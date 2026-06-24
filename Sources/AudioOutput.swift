import Foundation
import CoreAudio
import AudioToolbox

// MARK: - AudioOutput — list & switch the default system output device
//
// Pure CoreAudio HAL. No special permission needed: enumerating devices and
// changing the default output is a normal HAL property write. We also expose a
// software-volume setter for the current default output.

struct AudioDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let uid: String        // stable across reboots/reconnects — what we persist
    let name: String
}

enum AudioOutput {

    /// Every device that has at least one output channel.
    static func outputDevices() -> [AudioDevice] {
        var size = UInt32(0)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr,
            size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr
        else { return [] }

        return ids.compactMap { id -> AudioDevice? in
            guard hasOutputChannels(id), let uid = deviceUID(id) else { return nil }
            return AudioDevice(id: id, uid: uid, name: deviceName(id) ?? uid)
        }
    }

    /// The current default output device's UID, if any.
    static func currentDefaultUID() -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID) == noErr
        else { return nil }
        return deviceUID(deviceID)
    }

    /// Set the system default output device by its persistent UID. Returns true
    /// on success. Unknown/disconnected UIDs are a no-op (false).
    @discardableResult
    static func setDefaultOutput(uid: String) -> Bool {
        guard let device = outputDevices().first(where: { $0.uid == uid }) else { return false }
        var deviceID = device.id
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID)
        return status == noErr
    }

    /// Set the output volume (0...100) on the current default output device.
    /// Applies the scalar to whichever channels expose a volume control.
    @discardableResult
    static func setVolume(percent: Int) -> Bool {
        var deviceID = AudioDeviceID(0)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID) == noErr
        else { return false }

        var scalar = Float32(max(0, min(100, percent))) / 100.0
        var ok = false
        // Try the master element, then channels 1 & 2 (most devices use these).
        for element in [kAudioObjectPropertyElementMain, 1, 2] {
            var vaddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: AudioObjectPropertyElement(element))
            if AudioObjectHasProperty(deviceID, &vaddr) {
                var settable: DarwinBoolean = false
                if AudioObjectIsPropertySettable(deviceID, &vaddr, &settable) == noErr,
                   settable.boolValue {
                    let status = AudioObjectSetPropertyData(
                        deviceID, &vaddr, 0, nil,
                        UInt32(MemoryLayout<Float32>.size), &scalar)
                    if status == noErr { ok = true }
                }
            }
        }
        return ok
    }

    // MARK: - private helpers

    private static func hasOutputChannels(_ id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0
        else { return false }
        let bufList = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufList.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, bufList) == noErr
        else { return false }
        let abl = UnsafeMutableAudioBufferListPointer(
            bufList.assumingMemoryBound(to: AudioBufferList.self))
        for buffer in abl where buffer.mNumberChannels > 0 { return true }
        return false
    }

    private static func deviceUID(_ id: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var uid: CFString? = nil
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &uid) {
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
        }
        guard status == noErr else { return nil }
        return uid as String?
    }

    private static func deviceName(_ id: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var name: CFString? = nil
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &name) {
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
        }
        guard status == noErr else { return nil }
        return name as String?
    }
}

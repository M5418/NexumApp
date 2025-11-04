# Resolve FLUTTER_ROOT from Generated.xcconfig and require Flutter SDK's podhelper
def __flutter_sdk_root_from_xcconfig__
  # Try ios/Flutter first (typical location when called from Podfile)
  generated = File.expand_path(File.join(__dir__, '..', 'ios', 'Flutter', 'Generated.xcconfig'))
  # Fallback to local Flutter folder if running from different context
  unless File.exist?(generated)
    generated = File.expand_path(File.join(__dir__, 'Generated.xcconfig'))
  end
  unless File.exist?(generated)
    raise "Generated.xcconfig not found to resolve FLUTTER_ROOT (looked for #{generated})"
  end
  File.foreach(generated) do |line|
    match = line.match(/FLUTTER_ROOT\=(.*)/)
    return match[1].strip if match
  end
  raise "FLUTTER_ROOT not found in Generated.xcconfig"
end
__flutter_root__ = __flutter_sdk_root_from_xcconfig__
require File.expand_path(File.join(__flutter_root__, 'packages', 'flutter_tools', 'bin', 'podhelper'))

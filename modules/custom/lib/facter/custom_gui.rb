# frozen_string_literal: true

Facter.add(:custom_gui) do
  confine kernel: 'Linux'

  setcode do
    default_target = begin
      File.realpath('/etc/systemd/system/default.target')
    rescue StandardError
      ''
    end

    graphical_default = default_target.end_with?('/graphical.target')
    display_manager = File.exist?('/etc/systemd/system/display-manager.service') ||
                      File.symlink?('/etc/systemd/system/display-manager.service')
    graphical_sessions = Dir.glob('/usr/share/{xsessions,wayland-sessions}/*.desktop').any?
    active_display = Dir.glob('/tmp/.X11-unix/X*').any? ||
                     Dir.glob('/run/user/*/wayland-*').any?

    graphical_sessions && (graphical_default || display_manager || active_display)
  end
end

#!/usr/bin/env ruby

tm_dialog = ENV["DIALOG"]
Dir.chdir(ENV["TM_PROJECT_DIRECTORY"])

routes = %x(spring rake routes).gsub(/^ *([a-z0-9_]+)?.*$/, '\1').gsub(/^\s*$\n/, "").split("\n").map do |route|
  %w(_path).map { |extension| "{ display = #{route.to_s + extension}; }" }
end

%x(#{tm_dialog} popup --returnChoice --suggestions '( #{routes.flatten.join(", ")} )')

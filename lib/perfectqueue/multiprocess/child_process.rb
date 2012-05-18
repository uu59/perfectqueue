#
# PerfectQueue
#
# Copyright (C) 2012 FURUHASHI Sadayuki
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

module PerfectQueue
  module Multiprocess

    class ChildProcess < ThreadProcessor
      def self.run(runner, config, wpipe)
        new(runner, config, wpipe).run
      end

      def initialize(runner, config, wpipe)
        @wpipe = wpipe
        @wpipe.sync = true
        super(runner, config)
        @sig = install_signal_handlers
      end

      def run
        super
        @sig.shutdown
      end

      def stop(immediate)
        @log.info "Exiting worker pid=#{Process.pid}"
        super
      end

      def child_heartbeat
        @wpipe.write HEARTBEAT_PACKET
      rescue
        @log.error "Parent process unexpectedly died. Exiting worker pid=#{Process.pid}: #{$!}"
        stop(true)
        Process.kill(:KILL, Process.pid)
        exit! 137
      end

      HEARTBEAT_PACKET = [0].pack('C')

      private
      def install_signal_handlers
        SignalQueue.start do |sig|
          sig.trap :TERM do
            stop(false)
          end
          sig.trap :INT do
            stop(false)
          end

          sig.trap :QUIT do
            stop(true)
          end

          sig.trap :USR1 do
            stop(false)
          end

          sig.trap :USR2 do
            stop(true)
          end

          sig.trap :HUP do
            stop(false)
          end

          sig.trap :WINCH do
            stop(true)
          end

          sig.trap :SIGCONT do
            # do nothing?
          end
        end
      end
    end

  end
end

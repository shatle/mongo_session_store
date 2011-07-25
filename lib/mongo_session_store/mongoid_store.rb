begin
  require 'mongoid'

  module ActionDispatch
    module Session
      class MongoidStore < AbstractStore
      
        class Session
          include Mongoid::Document
          include Mongoid::Timestamps
          self.collection_name = MongoSessionStore.collection_name
        
          identity :type => String

          field :data, :type => BSON::Binary, :default => BSON::Binary.new(Marshal.dump({}))
        end

        # The class used for session storage.
        cattr_accessor :session_class
        self.session_class = Session

        SESSION_RECORD_KEY = 'rack.session.record'.freeze
        begin
          ENV_SESSION_OPTIONS_KEY = Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY
        rescue NameError
          # Rack 1.2.x has access to the ENV_SESSION_OPTIONS_KEY
        end

        private

          def generate_sid
            # 20 random bytes in url-safe base64
            SecureRandom.base64(20).gsub('=','').gsub('+','-').gsub('/','_')
          end

          def get_session(env, sid)
            sid ||= generate_sid

            session = find_session(sid)
            env[SESSION_RECORD_KEY] = session
            [sid, unpack(session.data)]
          end

          def set_session(env, sid, session_data, options = {})
            record = get_session_model(env, sid)
            record.data = pack(session_data)

            # Rack spec dictates that set_session should return true or false
            # depending on whether or not the session was saved or not.
            # However, ActionPack seems to want a session id instead.
            record.save ? sid : false
          end

          def find_session(id)   
            @@session_class.where(:_id => id).first || @@session_class.new(:_id => id)
          end
        
          def destroy_session(env, session_id, options)
            destroy(env)
            generate_sid unless options[:drop]
          end
          
          def destroy(env)
            if sid = current_session_id(env)
              get_session_model(env, sid).destroy
              env[SESSION_RECORD_KEY] = nil
            end
          end
        
          def get_session_model(env, sid)
            if env[ENV_SESSION_OPTIONS_KEY][:id].nil?
              env[SESSION_RECORD_KEY] = find_session(sid)
            else
              env[SESSION_RECORD_KEY] ||= find_session(sid)
            end
          end

          def pack(data)
            BSON::Binary.new(Marshal.dump(data))
          end

          def unpack(packed)
            return nil unless packed
            Marshal.load(StringIO.new(packed.to_s))
          end
      
      end
    end
  end

rescue LoadError
end
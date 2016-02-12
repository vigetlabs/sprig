require "database_cleaner/mongoid"
require "socket"
require "open3"

MONGO_TEST_CONTAINER = "sprig-mongo-test"
MONGO_TEST_HOST = "localhost"
MONGO_TEST_PORT = 27017
MONGO_REPLICA_SET = "rs0"

def mongo_port_open?
  TCPSocket.new(MONGO_TEST_HOST, MONGO_TEST_PORT).close
  true
rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError
  false
end

def mongo_container_exists?
  Open3.capture2("docker", "ps", "-aq", "-f", "name=^/#{MONGO_TEST_CONTAINER}$").first.strip != ""
end

def mongo_container_has_replica_set?
  Open3.capture2("docker", "inspect", "--format", "{{json .Args}}", MONGO_TEST_CONTAINER)
    .first.strip.include?("--replSet")
end

def wait_for_mongo_port!(timeout: 30)
  deadline = Time.now + timeout

  until mongo_port_open?
    if Time.now > deadline
      abort "MongoDB container '#{MONGO_TEST_CONTAINER}' did not become reachable on " \
        "#{MONGO_TEST_HOST}:#{MONGO_TEST_PORT} within #{timeout}s."
    end

    sleep 0.5
  end
end

def mongosh_eval(container, js)
  Open3.capture2("docker", "exec", container, "mongosh", "--quiet", "--eval", js).first.strip
end

def replica_set_initiated?
  mongosh_eval(MONGO_TEST_CONTAINER, "rs.status().ok") == "1"
end

def replica_set_has_primary?
  mongosh_eval(MONGO_TEST_CONTAINER, "rs.status().members.some(m => m.stateStr === 'PRIMARY')") == "true"
end

def initiate_replica_set!
  return if replica_set_initiated?

  mongosh_eval(MONGO_TEST_CONTAINER, <<~JS)
    rs.initiate({
      _id: "#{MONGO_REPLICA_SET}",
      members: [{ _id: 0, host: "#{MONGO_TEST_HOST}:#{MONGO_TEST_PORT}" }]
    })
  JS
end

def wait_for_replica_set_primary!(timeout: 30)
  deadline = Time.now + timeout

  until replica_set_has_primary?
    if Time.now > deadline
      abort "MongoDB replica set '#{MONGO_REPLICA_SET}' did not elect a primary within #{timeout}s."
    end

    sleep 0.5
  end
end

def start_mongo_container!
  if mongo_container_exists? && !mongo_container_has_replica_set?
    system("docker", "rm", "-f", MONGO_TEST_CONTAINER, out: File::NULL, err: File::NULL)
  end

  if mongo_container_exists?
    system("docker", "start", MONGO_TEST_CONTAINER, out: File::NULL, err: File::NULL)
  else
    system("docker", "run", "-d", "--name", MONGO_TEST_CONTAINER,
      "-p", "#{MONGO_TEST_PORT}:#{MONGO_TEST_PORT}",
      "--tmpfs", "/data/db:size=256m", "--tmpfs", "/data/configdb:size=64m",
      "mongo:8", "--replSet", MONGO_REPLICA_SET, out: File::NULL, err: File::NULL)
  end
end

def ensure_mongo_running!
  return if mongo_port_open?

  unless system("docker", "info", out: File::NULL, err: File::NULL)
    abort "MongoDB isn't reachable on #{MONGO_TEST_HOST}:#{MONGO_TEST_PORT}, and Docker isn't " \
      "available to start it. Install/start Docker, or start a single-node replica set " \
      "MongoDB yourself on that host/port (Sprig's Mongoid transaction support requires one)."
  end

  start_mongo_container!
  wait_for_mongo_port!
  initiate_replica_set!
  wait_for_replica_set_primary!
end

ensure_mongo_running!

RSpec.configure do |c|
  c.before(:suite) do
    DatabaseCleaner[:mongoid].strategy = :deletion
    DatabaseCleaner[:mongoid].clean_with(:deletion)
  end

  c.before(:each) do
    DatabaseCleaner[:mongoid].start
  end

  c.after(:each) do
    DatabaseCleaner[:mongoid].clean
  end
end

# Datastore
Mongoid.load!(File.join(File.dirname(__FILE__), "mongoid.yml"))

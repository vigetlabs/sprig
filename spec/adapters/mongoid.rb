require "database_cleaner/mongoid"
require "socket"

MONGO_TEST_CONTAINER = "sprig-mongo-test"
MONGO_TEST_HOST = "localhost"
MONGO_TEST_PORT = 27017

def mongo_port_open?
  TCPSocket.new(MONGO_TEST_HOST, MONGO_TEST_PORT).close
  true
rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError
  false
end

def mongo_container_exists?
  `docker ps -aq -f name=^/#{MONGO_TEST_CONTAINER}$`.strip != ""
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

def ensure_mongo_running!
  return if mongo_port_open?

  unless system("docker", "info", out: File::NULL, err: File::NULL)
    abort "MongoDB isn't reachable on #{MONGO_TEST_HOST}:#{MONGO_TEST_PORT}, and Docker isn't " \
      "available to start it. Install/start Docker, or start MongoDB yourself on that host/port."
  end

  if mongo_container_exists?
    system("docker", "start", MONGO_TEST_CONTAINER, out: File::NULL, err: File::NULL)
  else
    system("docker", "run", "-d", "--name", MONGO_TEST_CONTAINER,
      "-p", "#{MONGO_TEST_PORT}:#{MONGO_TEST_PORT}",
      "--tmpfs", "/data/db:size=256m", "--tmpfs", "/data/configdb:size=64m",
      "mongo:8", out: File::NULL, err: File::NULL)
  end

  wait_for_mongo_port!
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

require "pstore"
require "serialport"
require 'mqtt'




#params for serial port
port_str = "/dev/tty.usbmodem1421"  #may be different for you
baud_rate = 115200
data_bits = 8
stop_bits = 1
parity = SerialPort::NONE

sp = SerialPort.new(port_str, baud_rate, data_bits, stop_bits, parity)

MESSAGE_TYPE_PRESENTATION = 0
MESSAGE_TYPE_SET = 1
MESSAGE_TYPE_REQ = 2
MESSAGE_TYPE_INTERNAL = 3
MESSAGE_TYPE_STREAM = 4

INTERNAL_ID_REQUEST = 3
INTERNAL_ID_RESPONSE = 4

BROADCAST_NODE_ID = 255

NO_ACK = 0

def allocateNextNodeId
	store = PStore.new("data.pstore")
	
	nextNodeId=9999

	store.transaction do
  		currentNodeId = store.fetch(:currentNodeId, 0)
		puts "current node id is: #{currentNodeId}"
		nextNodeId = currentNodeId + 1
		store[:currentNodeId] = nextNodeId
		store.commit
	end
	nextNodeId
end


def processInternal(sp, subType, payload)
	puts "Internal message: #{payload}"
	case subType.to_i
		when INTERNAL_ID_REQUEST
			newNodeId = allocateNextNodeId
			puts "Allocating new node id: #{newNodeId}"
			message = "#{BROADCAST_NODE_ID};#{BROADCAST_NODE_ID};#{MESSAGE_TYPE_INTERNAL};#{NO_ACK};#{INTERNAL_ID_RESPONSE};#{newNodeId}\r\n"
			puts "sending #{message}"
			sp.write(message)	
	end
end

def processLine(sp, c, line)
	puts "received line: #{line}"
	nodeId, sensorId, messageType, ack, subType, payload = line.split(';')
	case messageType.to_i
		when MESSAGE_TYPE_SET
			message = "Set message: #{nodeId} #{payload}"
                	puts message
                	c.publish('mysensors-data', message)
		when MESSAGE_TYPE_INTERNAL
			processInternal(sp,subType, payload)		
	end
end


MQTT::Client.connect('localhost') do |c|

#just read forever
while true do
   while (i = sp.readline("\n").chomp) do       # see note 2
      processLine(sp,c,i)
    end
end

sp.close                       #see note 1
end

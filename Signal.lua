local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Signal.new()
	return setmetatable({
		_head = nil,
		_destroyed = false,
	}, Signal)
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end

	self.Connected = false

	local signal = self._signal

	if signal._head == self then
		signal._head = self._next
		return
	end

	local node = signal._head

	while node do
		if node._next == self then
			node._next = self._next
			return
		end

		node = node._next
	end
end

function Signal:Connect(callback)
	assert(type(callback) == "function", "callback must be a function")

	local connection = setmetatable({
		Connected = true,
		Callback = callback,
		_signal = self,
		_next = self._head,
	}, Connection)

	self._head = connection

	return connection
end

function Signal:Once(callback)
	local connection

	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)

	return connection
end

function Signal:Fire(...)
	local node = self._head

	while node do
		if node.Connected then
			task.spawn(node.Callback, ...)
		end

		node = node._next
	end
end

function Signal:Wait()
	local thread = coroutine.running()

	local connection

	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)

	return coroutine.yield()
end

function Signal:DisconnectAll()
	local node = self._head

	while node do
		node.Connected = false
		node = node._next
	end

	self._head = nil
end

function Signal:Destroy()
	self:DisconnectAll()
	self._destroyed = true
end

return Signal

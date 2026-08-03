local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		_connections = {},
	}, Signal)
end

function Signal:Connect(callback)
	local connection = {
		Connected = true,
	}

	function connection:Disconnect()
		if not self.Connected then
			return
		end

		self.Connected = false
	end

	connection.Callback = callback
	table.insert(self._connections, connection)

	return connection
end

function Signal:Fire(...)
	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			task.spawn(connection.Callback, ...)
		end
	end
end

function Signal:Destroy()
	table.clear(self._connections)
end

return Signal

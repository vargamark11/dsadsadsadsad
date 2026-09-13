--!strict
--[[
    Signal.luau
    High-performance pure Luau event signal implementation.
    Allows decoupled observer pattern without relying on BindableEvents.
]]

export type Connection = {
    Connected: boolean,
    Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
    Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
    Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
    Fire: (self: Signal<T...>, T...) -> (),
    Wait: (self: Signal<T...>) -> T...,
    Destroy: (self: Signal<T...>) -> (),
}

type Node<T...> = {
    fn: (T...) -> (),
    next: Node<T...>?,
    prev: Node<T...>?,
    disconnected: boolean,
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
    local self = setmetatable({
        _head = nil :: Node<T...>?,
        _tail = nil :: Node<T...>?,
    }, Signal)
    return (self :: any) :: Signal<T...>
end

function Signal:Connect<T...>(fn: (T...) -> ()): Connection
    local node: Node<T...> = {
        fn = fn,
        next = nil,
        prev = self._tail,
        disconnected = false,
    }

    if self._tail then
        self._tail.next = node
        self._tail = node
    else
        self._head = node
        self._tail = node
    end

    local connection: Connection
    connection = {
        Connected = true,
        Disconnect = function(conn)
            if not conn.Connected then return end
            conn.Connected = false
            node.disconnected = true

            if node.prev then
                node.prev.next = node.next
            else
                self._head = node.next
            end

            if node.next then
                node.next.prev = node.prev
            else
                self._tail = node.prev
            end
        end,
    }

    return connection
end

function Signal:Once<T...>(fn: (T...) -> ()): Connection
    local connection: Connection
    connection = self:Connect(function(...)
        connection:Disconnect()
        fn(...)
    end)
    return connection
end

function Signal:Fire<T...>(...: T...)
    local current = self._head
    while current do
        local nextNode = current.next
        if not current.disconnected then
            task.spawn(current.fn, ...)
        end
        current = nextNode
    end
end

function Signal:Wait<T...>(): T...
    local thread = coroutine.running()
    local conn: Connection
    conn = self:Connect(function(...)
        conn:Disconnect()
        task.spawn(thread, ...)
    end)
    return coroutine.yield()
end

function Signal:Destroy()
    local current = self._head
    while current do
        current.disconnected = true
        current = current.next
    end
    self._head = nil
    self._tail = nil
end

return Signal

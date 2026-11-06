--!nocheck
--!nolint

local __ANTIBRAIN_MODULES = {cache = {}}

do
    do
        local function __modImpl()
            local Failure = {}

            Failure.traceback = function(problem)
                local ok, text = pcall(tostring, problem)

                return debug.traceback((ok and {text} or {
                    'An unprintable error was raised',
                })[1], 2)
            end
            Failure.capture = function(callback, ...)
                local ok, message = xpcall(callback, Failure.traceback, ...)

                return (ok and {nil} or {message})[1]
            end

            function Failure.summary(failure)
                return failure:split('\n')[1]
            end

            return table.freeze(Failure)
        end

        function __ANTIBRAIN_MODULES.a()
            local v = __ANTIBRAIN_MODULES.cache.a

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.a = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            return table.freeze({})
        end

        function __ANTIBRAIN_MODULES.b()
            local v = __ANTIBRAIN_MODULES.cache.b

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.b = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Failure = __ANTIBRAIN_MODULES.a()
            local REPORTS_PER_CONNECTION = 5
            local HIDDEN_NOTICE = 'Further errors from this connection are not reported.'
            local REPORTS_PER_SCOPE = 10
            local Class = {}

            Class.__index = Class

            local Scope = {}

            function Scope.new(report, label)
                local fields = {
                    closed = false,
                    label = label,
                    _report = report,
                    _tail = nil,
                    _reported = {},
                    _reports = 0,
                }

                return setmetatable(fields, Class)
            end

            local function fail(scope, failure)
                if not failure then
                    return
                end

                local text = (scope.label and {
                    string.format('[%s] %s', tostring(scope.label), tostring(failure)),
                } or {failure})[1]
                local report = scope._report

                if report then
                    pcall(report, text)
                else
                    warn(text)
                end
            end
            local function unlink(scope, entry)
                if not entry.attached then
                    return
                end

                entry.attached = false

                if entry.previous then
                    entry.previous.next = entry.next
                end
                if entry.next then
                    entry.next.previous = entry.previous
                else
                    scope._tail = entry.previous
                end

                entry.previous = nil
                entry.next = nil
            end
            local function dispose(scope, cleanup)
                fail(scope, Failure.capture(cleanup))
            end

            function Class.add(self, cleanup)
                if self.closed then
                    dispose(self, cleanup)

                    return function() end
                end

                local tail = self._tail
                local entry = {
                    cleanup = cleanup,
                    previous = tail,
                    next = nil,
                    attached = true,
                }

                if tail then
                    tail.next = entry
                end

                self._tail = entry

                return function()
                    unlink(self, entry)
                end
            end

            local function release(object)
                local kind = typeof(object)

                if kind == 'Instance' then
                    object:Destroy()
                elseif kind == 'RBXScriptConnection' then
                    object:Disconnect()
                elseif kind == 'table' and type(object.Destroy) == 'function' then
                    object:Destroy()
                else
                    object:Remove()
                end
            end

            function Scope.own(scope, object)
                scope:add(function()
                    release(object)
                end)

                return object
            end
            function Class.child(self, label)
                local child = Scope.new(self._report, label or self.label)
                local detach = self:add(function()
                    child:close()
                end)

                child:add(detach)

                return child
            end
            function Class.detached(self, label)
                return Scope.new(self._report, label or self.label)
            end
            function Class.report(self, failure)
                local line = failure:match('^[^\n]*') or failure

                if self._reported[line] or self._reports >= REPORTS_PER_SCOPE then
                    return
                end

                self._reported[line] = true
                self._reports = self._reports + 1

                fail(self, failure)
            end
            function Class.connect(self, signal, callback)
                local reported = {}
                local remaining = REPORTS_PER_CONNECTION
                local connection = signal:Connect(function(...)
                    if self.closed then
                        return
                    end

                    local failure = Failure.capture(callback, ...)

                    if not failure or remaining == 0 then
                        return
                    end

                    local line = Failure.summary(failure)

                    if reported[line] then
                        return
                    end

                    reported[line] = true
                    remaining = remaining - 1

                    fail(self, (remaining == 0 and {
                        string.format('%s\n%s', tostring(failure), tostring(HIDDEN_NOTICE)),
                    } or {failure})[1])
                end)

                self:add(function()
                    connection:Disconnect()
                end)

                return connection
            end

            local function launch(self, callback, args, schedule)
                local detach = function() end
                local worker = coroutine.create(function()
                    if self.closed then
                        detach()

                        return
                    end

                    local failure = Failure.capture(callback, table.unpack(args, 1, args.n))

                    detach()
                    fail(self, failure)
                end)

                if self.closed then
                    return worker
                end

                detach = self:add(function()
                    if coroutine.status(worker) == 'suspended' then
                        task.cancel(worker)
                    end
                end)

                local failure = Failure.capture(schedule, worker)

                if failure then
                    detach()
                    error(failure, 0)
                end

                return worker
            end

            function Class.spawn(self, callback, ...)
                return launch(self, callback, table.pack(...), function(worker)
                    task.spawn(worker)
                end)
            end
            function Class.defer(self, callback, ...)
                return launch(self, callback, table.pack(...), function(worker)
                    task.defer(worker)
                end)
            end
            function Class.delay(self, seconds, callback, ...)
                assert(seconds >= 0 and seconds < math.huge, 'Delay must be finite and nonnegative')

                return launch(self, callback, table.pack(...), function(worker)
                    task.delay(seconds, worker)
                end)
            end
            function Class.close(self)
                if self.closed then
                    return
                end

                self.closed = true

                local entry = self._tail

                while entry do
                    unlink(self, entry)
                    dispose(self, entry.cleanup)

                    entry = self._tail
                end
            end

            return table.freeze(Scope)
        end

        function __ANTIBRAIN_MODULES.c()
            local v = __ANTIBRAIN_MODULES.cache.c

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.c = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            __ANTIBRAIN_MODULES.b()
            __ANTIBRAIN_MODULES.c()

            return table.freeze({})
        end

        function __ANTIBRAIN_MODULES.d()
            local v = __ANTIBRAIN_MODULES.cache.d

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.d = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Failure = __ANTIBRAIN_MODULES.a()
            local Scope = __ANTIBRAIN_MODULES.c()
            local Class = {}

            Class.__index = Class

            function Class.start(self, initialize)
                if self._initialized or self.state ~= 'starting' then
                    return 'Session already started or stopped'
                end

                self._initialized = true

                local failure = Failure.capture(initialize, self.scope)

                if failure then
                    self:stop()

                    return failure
                end
                if self.state ~= 'starting' or self.scope.closed then
                    self:stop()

                    return 'Session superseded'
                end

                self.state = 'running'

                return nil
            end
            function Class.stop(self)
                if self.state == 'stopping' or self.state == 'stopped' then
                    return
                end

                self.state = 'stopping'

                self.scope:close()

                self.state = 'stopped'
            end

            local Session = {}

            function Session.new(report)
                local fields = {
                    state = 'starting',
                    scope = Scope.new(report),
                    _initialized = false,
                }

                return setmetatable(fields, Class)
            end

            return table.freeze(Session)
        end

        function __ANTIBRAIN_MODULES.e()
            local v = __ANTIBRAIN_MODULES.cache.e

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.e = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            __ANTIBRAIN_MODULES.c()
            __ANTIBRAIN_MODULES.e()

            return table.freeze({})
        end

        function __ANTIBRAIN_MODULES.f()
            local v = __ANTIBRAIN_MODULES.cache.f

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.f = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            __ANTIBRAIN_MODULES.b()
            __ANTIBRAIN_MODULES.d()
            __ANTIBRAIN_MODULES.f()
            __ANTIBRAIN_MODULES.c()

            return table.freeze({})
        end

        function __ANTIBRAIN_MODULES.g()
            local v = __ANTIBRAIN_MODULES.cache.g

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.g = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            __ANTIBRAIN_MODULES.g()

            local function register(routes, ids, definition, kind)
                for _, id in ids do
                    assert(id >= 1 and id % 1 == 0, string.format('Game "%s": %s id %s is not a positive integer', tostring(definition.id), tostring(kind), tostring(id)))

                    local owner = routes[id]

                    assert(owner == nil, string.format('Game "%s": %s id %s is already registered by "%s"', tostring(definition.id), tostring(kind), tostring(id), tostring(owner and owner.id)))

                    routes[id] = definition
                end
            end

            local Registry = {}

            function Registry.select(catalog, placeId, universeId)
                local seen = {}
                local places, universes = {}, {}

                for _, definition in catalog do
                    local id = definition.id

                    assert(id:match('^[a-z][a-z0-9_-]*$'), string.format(
[[Game "%s": the id must use lowercase letters, digits, - or _]], tostring(id)))
                    assert(not seen[id], string.format('Game "%s": the id is registered twice', tostring(id)))
                    assert(definition.name:match('%S'), string.format('Game "%s": the name is blank', tostring(id)))

                    seen[id] = true

                    register(universes, definition.universeIds, definition, 'universe')
                    register(places, definition.placeIds or {}, definition, 'place')
                end

                return places[placeId] or universes[universeId]
            end

            return table.freeze(Registry)
        end

        function __ANTIBRAIN_MODULES.h()
            local v = __ANTIBRAIN_MODULES.cache.h

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.h = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Failure = __ANTIBRAIN_MODULES.a()

            __ANTIBRAIN_MODULES.g()
            __ANTIBRAIN_MODULES.d()
            __ANTIBRAIN_MODULES.f()

            local Registry = __ANTIBRAIN_MODULES.h()

            __ANTIBRAIN_MODULES.c()

            local Session = __ANTIBRAIN_MODULES.e()

            local function replacePrevious(slot)
                local previous = slot.current

                if not previous then
                    return nil
                end
                if previous.state == 'stopping' then
                    return 'Previous session is still stopping'
                end

                local failure = Failure.capture(previous.stop, previous)

                if failure then
                    return string.format('Previous session failed to stop: %s', tostring(failure))
                end
                if previous.state ~= 'stopped' then
                    return 'Previous session did not stop'
                end
                if slot.current and slot.current ~= previous then
                    return 'A newer session has started'
                end

                return nil
            end
            local function missingApis(definition, platform)
                local missing = {}
                local requires = definition.requires or {}

                for _, name in requires do
                    if not platform.supports(name) then
                        table.insert(missing, name)
                    end
                end

                return missing
            end

            local ALERT_SECONDS = 30
            local ALERT_LENGTH = 120

            local function reporter(platform, alerts)
                return function(failure)
                    platform.log(failure)

                    local notify = alerts.notify
                    local now = os.clock()

                    if notify and now - alerts.last >= ALERT_SECONDS then
                        alerts.last = now

                        local summary = Failure.summary(failure):sub(1, ALERT_LENGTH)

                        Failure.capture(notify, string.format('Something hit an error: %s The console has the details.', tostring(summary)))
                    end
                end
            end
            local function open(deps, session, owner, module, problem, alerts)
                local mounted = deps.mount({
                    scope = owner:child(),
                    persistence = deps.platform.persistence,
                    module = module,
                    problem = problem,
                    stop = function()
                        if not owner.closed then
                            session:stop()
                        end
                    end,
                    log = deps.platform.log,
                    report = reporter(deps.platform, alerts),
                })

                alerts.notify = mounted.game.notify

                return mounted
            end
            local function finish(deps, ui)
                local failure = Failure.capture(ui.ready)

                if failure then
                    deps.platform.log(string.format('Settings could not finish loading: %s', tostring(failure)))
                end
            end
            local function prepare(deps, module)
                local failure = Failure.capture(function()
                    local reason = deps.platform.prepare(module)

                    if reason then
                        deps.platform.log(string.format("The hub's folders are not all there: %s", tostring(reason)))
                    end
                end)

                if failure then
                    deps.platform.log(string.format("The hub's folders could not be made: %s", tostring(failure)))
                end
            end
            local function startModule(
                deps,
                session,
                scope,
                definition,
                shown,
                alerts
            )
                local platform = deps.platform
                local missing = missingApis(definition, platform)

                if #missing > 0 then
                    local list = table.concat(missing, ', ')

                    platform.log(string.format('%s needs %s, which %s does not provide', tostring(definition.name), tostring(list), tostring(platform.executor)))

                    return {
                        name = definition.name,
                        reason = string.format('%s does not provide %s.', tostring(platform.executor), tostring(list)),
                    }
                end

                prepare(deps, definition.id)

                if scope.closed then
                    return nil
                end

                local attempt = scope:child()
                local ui = open(deps, session, attempt, {
                    id = definition.id,
                    name = definition.name,
                }, shown, alerts)

                if scope.closed then
                    return nil
                end

                local failure = Failure.capture(definition.start, {
                    game = platform.game,
                    scope = attempt:child(),
                    ui = ui.game,
                    log = function(message)
                        platform.log(string.format('%s: %s', tostring(definition.name), tostring(message)))
                    end,
                    wait = platform.wait,
                    services = {},
                })

                if scope.closed then
                    return nil
                end
                if not failure then
                    finish(deps, ui)

                    return nil
                end

                platform.log(string.format('%s failed to start: %s', tostring(definition.name), tostring(failure)))
                attempt:close()

                return {
                    name = definition.name,
                    reason = string.format('It failed to start: %s. The full error is in the console.', tostring(Failure.summary(failure))),
                }
            end

            local App = {}

            function App.launch(deps)
                local platform = deps.platform
                local slot = platform.slot
                local conflict = replacePrevious(slot)

                if conflict then
                    return nil, conflict
                end

                local alerts = {
                    notify = nil,
                    last = -math.huge,
                }
                local session = Session.new(reporter(platform, alerts))

                slot.current = session

                session.scope:add(function()
                    if slot.current == session then
                        slot.current = nil
                    end
                end)

                local failure = session:start(function(scope)
                    if platform.initialize then
                        platform.initialize(scope)
                    end
                    if scope.closed then
                        return
                    end

                    prepare(deps, nil)

                    if scope.closed then
                        return
                    end

                    local definition = Registry.select(deps.catalog, platform.game.placeId, platform.game.universeId)
                    local problem = (definition and {
                        (startModule(deps, session, scope, definition, nil, alerts)),
                    } or {nil})[1]

                    if (definition and not problem) or scope.closed then
                        return
                    end

                    local universal = deps.universal

                    if universal then
                        local universalProblem = startModule(deps, session, scope, universal, problem, alerts)

                        if not universalProblem or scope.closed then
                            return
                        end

                        problem = problem or universalProblem
                    end

                    local ui = open(deps, session, scope, nil, problem, alerts)

                    if not scope.closed then
                        finish(deps, ui)
                    end
                end)

                if failure then
                    return nil, failure
                end

                return session, nil
            end

            return table.freeze(App)
        end

        function __ANTIBRAIN_MODULES.i()
            local v = __ANTIBRAIN_MODULES.cache.i

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.i = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local GameCode = {}
            local requireFound = require

            function GameCode.find(label, root, names)
                local current = root

                for _, name in names do
                    local found = current:FindFirstChild(name)

                    assert(found, string.format('%s %s is unavailable: %s is missing', tostring(label), tostring(table.concat(names, '.')), tostring(name)))

                    current = found
                end

                return current
            end
            function GameCode.load(label, root, names)
                local module = GameCode.find(label, root, names)

                assert(module:IsA('ModuleScript'), string.format('%s %s is not a module', tostring(label), tostring(table.concat(names, '.'))))

                return requireFound(module)
            end

            return table.freeze(GameCode)
        end

        function __ANTIBRAIN_MODULES.j()
            local v = __ANTIBRAIN_MODULES.cache.j

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.j = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local function protect(service)
                if type(cloneref) ~= 'function' then
                    return service
                end

                local ok, clone = pcall(cloneref, service)

                return (ok and typeof(clone) == 'Instance' and {clone} or {service})[1]
            end

            local cache = {}
            local resolve = function(_, name)
                local service = cache[name]

                if not service then
                    service = protect(game:GetService(name))
                    cache[name] = service
                end

                return service
            end
            local Services = setmetatable({}, {__index = resolve})

            return ((table.freeze(Services)))
        end

        function __ANTIBRAIN_MODULES.k()
            local v = __ANTIBRAIN_MODULES.cache.k

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.k = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local GameCode = __ANTIBRAIN_MODULES.j()
            local Services = __ANTIBRAIN_MODULES.k()

            local function find(root, names)
                return GameCode.find('RIVALS', root, names)
            end
            local function load(root, names)
                return GameCode.load('RIVALS', root, names)
            end
            local function player()
                return assert(Services.Players.LocalPlayer, 'RIVALS LocalPlayer is unavailable')
            end

            local scripts = nil

            local function playerScripts()
                local held = scripts

                if held then
                    return held
                end

                local found = find(player(), {
                    'PlayerScripts',
                })

                scripts = found

                return found
            end
            local function client(names)
                local path = table.clone(names)

                table.insert(path, 1, 'Modules')

                return load(playerScripts(), path)
            end

            local Modules = {}

            Modules.player = player

            function Modules.controller(name)
                return load(playerScripts(), {
                    'Controllers',
                    name,
                })
            end

            Modules.client = client

            local function under(folder, names)
                local path = table.clone(names)

                table.insert(path, 1, folder)

                return find(playerScripts(), path)
            end

            function Modules.interface(names)
                return under('UserInterface', names)
            end
            function Modules.asset(names)
                return under('Assets', names)
            end
            function Modules.shared(name)
                return load(Services.ReplicatedStorage, {
                    'Modules',
                    name,
                })
            end
            function Modules.remote(names)
                local path = table.clone(names)

                table.insert(path, 1, 'Remotes')

                return find(Services.ReplicatedStorage, path)
            end
            function Modules.viewModels()
                return Modules.asset({
                    'ViewModels',
                })
            end

            return table.freeze(Modules)
        end

        function __ANTIBRAIN_MODULES.l()
            local v = __ANTIBRAIN_MODULES.cache.l

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.l = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Failure = __ANTIBRAIN_MODULES.a()

            __ANTIBRAIN_MODULES.g()
            __ANTIBRAIN_MODULES.c()

            local Service = {}

            function Service.new(name, make)
                return table.freeze({
                    name = name,
                    make = make,
                })
            end
            function Service.use(run, services, service, ...)
                assert(not run.closed, string.format('Cannot use %s from a closed scope', tostring(service.name)))

                local entry = services[service]

                assert(not entry or not entry.initializing, string.format('%s is still being made', tostring(service.name)))

                if not entry then
                    local scope = run:detached(service.name)
                    local pending = {
                        value = nil,
                        scope = scope,
                        users = 0,
                        initializing = true,
                    }

                    services[service] = pending

                    local function discard()
                        if services[service] == pending then
                            services[service] = nil
                        end

                        scope:close()
                    end

                    local detach = run:add(discard)
                    local ok, made = xpcall(service.make, Failure.traceback, scope, services, 
...)

                    detach()

                    if not ok then
                        discard()
                        error(made, 0)
                    end
                    if run.closed or scope.closed then
                        discard()
                        error(string.format('%s was closed while it was being made', tostring(service.name)), 0)
                    end

                    pending.value, pending.initializing = made, false
                    entry = pending
                end

                local used = entry

                used.users = used.users + 1

                run:add(function()
                    used.users = used.users - 1

                    if used.users == 0 and services[service] == used then
                        services[service] = nil

                        used.scope:close()
                    end
                end)

                return used.value
            end
            function Service.value(name)
                return table.freeze({
                    name = name,
                    _value = nil,
                })
            end

            Service.get = function(services, value)
                return services[value]
            end

            function Service.set(services, value, current)
                services[value] = current
            end

            return table.freeze(Service)
        end

        function __ANTIBRAIN_MODULES.m()
            local v = __ANTIBRAIN_MODULES.cache.m

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.m = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Service = __ANTIBRAIN_MODULES.m()
            local REPORT = Service.value('ragebot report')
            local RageReport = {}

            RageReport.get = function(services)
                return Service.get(services, REPORT)
            end

            function RageReport.set(services, report)
                Service.set(services, REPORT, report)
            end

            return table.freeze(RageReport)
        end

        function __ANTIBRAIN_MODULES.n()
            local v = __ANTIBRAIN_MODULES.cache.n

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.n = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Fighter = {}

            Fighter.alive = function(fighter, player)
                if type(fighter) ~= 'table' or type(fighter.Items) ~= 'table' or #fighter.Items == 0 then
                    return false
                end

                local character = player.Character
                local humanoid = (character and {
                    (character:FindFirstChildOfClass('Humanoid')),
                } or {nil})[1]

                return humanoid ~= nil and humanoid.Health > 0
            end
            Fighter.invincible = function(fighter)
                local entity = fighter.Entity

                return type(entity) ~= 'table' or (entity._invincibility_visual and true or false)
            end
            Fighter.deflecting = function(fighter)
                local item = fighter.EquippedItem

                return type(item) == 'table' and item._deflect_hash and type(item._attack_cooldown) == 'number' and tick() < item._attack_cooldown
            end

            return table.freeze(Fighter)
        end

        function __ANTIBRAIN_MODULES.o()
            local v = __ANTIBRAIN_MODULES.cache.o

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.o = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Reaction = {}

            function Reaction.new()
                return {
                    targeted = false,
                    forgetAt = -math.huge,
                    readyAt = -math.huge,
                }
            end

            Reaction.step = function(
                reaction,
                found,
                now,
                reactionSeconds,
                forgetSeconds,
                suppressed
            )
                if found and reaction.readyAt == -math.huge then
                    reaction.readyAt = now + reactionSeconds
                end
                if not found then
                    if reaction.targeted then
                        reaction.forgetAt = now + forgetSeconds
                    end
                    if reaction.forgetAt < now then
                        reaction.readyAt = now + reactionSeconds
                    end
                end

                local ready = reaction.readyAt <= now and not suppressed

                reaction.targeted = found and ready

                return ready
            end

            return table.freeze(Reaction)
        end

        function __ANTIBRAIN_MODULES.p()
            local v = __ANTIBRAIN_MODULES.cache.p

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.p = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Services = __ANTIBRAIN_MODULES.k()
            local REACH = 9.5
            local FLOOR_DEPTH = 5
            local offsets = nil

            local function around()
                local cached = offsets

                if cached then
                    return cached
                end

                local list = {}

                for x = -1, 1 do
                    for y = -1, 1 do
                        for z = -1, 1 do
                            if x ~= 0 or y ~= 0 or z ~= 0 then
                                table.insert(list, Vector3.new(x, y, z).Unit * REACH)
                            end
                        end
                    end
                end

                offsets = list

                return list
            end

            local Sight = {}

            function Sight.new()
                return {
                    params = RaycastParams.new(),
                }
            end

            Sight.ignore = function(sight, instances)
                sight.params.FilterDescendantsInstances = instances
            end
            Sight.clear = function(sight, from, to)
                local hit = Services.Workspace:Raycast(from, to - from, sight.params)

                return hit == nil, hit
            end

            local fromAround = function(sight, origin, target)
                for _, offset in around()do
                    local from = origin + offset

                    if Sight.clear(sight, from, target) then
                        return true, {origin = from}
                    end
                end

                return false, nil
            end

            Sight.manipulate = function(
                sight,
                origin,
                target,
                character,
                melee
            )
                if melee then
                    return false, nil
                end
                if Sight.clear(sight, origin, target) then
                    return true, nil
                end

                local _, floor = Sight.clear(sight, origin, origin + Vector3.new(0, 
-FLOOR_DEPTH, 0))
                local ground = (floor and {
                    floor.Instance,
                } or {nil})[1]

                if not floor or not ground or not ground:IsA('BasePart') then
                    return fromAround(sight, origin, target)
                end

                local depth = floor.Distance + math.min(ground.Size.Y * 0.99, REACH - floor.Distance)
                local below = origin + Vector3.new(0, -depth, 0)

                if Sight.clear(sight, below, target) then
                    return true, {origin = below}
                end

                local body = character:FindFirstChild('HitboxBody')

                if not body or not body:IsA('BasePart') then
                    return fromAround(sight, origin, target)
                end

                local drop = Vector3.new(0, -body.Size.Y / 2.01, 0)

                if not Sight.clear(sight, below, body.Position + drop) then
                    return fromAround(sight, origin, target)
                end

                return true, {
                    origin = below,
                    part = body,
                    hitOffset = drop,
                }
            end

            return table.freeze(Sight)
        end

        function __ANTIBRAIN_MODULES.q()
            local v = __ANTIBRAIN_MODULES.cache.q

            if not v then
                v = {
                    c = __modImpl(),
                }
                __ANTIBRAIN_MODULES.cache.q = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Fighter = __ANTIBRAIN_MODULES.o()
            local Reaction = __ANTIBRAIN_MODULES.p()
            local Services = __ANTIBRAIN_MODULES.k()
            local Sight = __ANTIBRAIN_MODULES.q()
            local EYE, CROUCHED_EYE = 1.75, 0.25
            local NOT_BODY = table.freeze({
                HitboxBody = true,
                HitboxHead = true,
                PhysicalHitboxHead = true,
                HitboxBodySmall = true,
                HitboxHeadSmall = true,
                FakeMass = true,
            })
            local NOTHING = table.freeze({manipulated = false})
            local Targeting = {}
            local hasItem = function(fighter, name)
                for _, item in fighter.Items do
                    if item.Name == name then
                        return true
                    end
                end

                return false
            end
            local protected = function(fighter, ignoreIf, origin, position)
                if Fighter.invincible(fighter) then
                    return true
                end
                if ignoreIf['katana deflecting'] and Fighter.deflecting(fighter) then
                    return true
                end

                local item = fighter.EquippedItem

                if ignoreIf['blocked by riot shield'] then
                    local holding = type(item) == 'table' and item.Name == 'Riot Shield'

                    if holding or hasItem(fighter, 'Riot Shield') then
                        local turn = ((position - origin).Unit - fighter:GetRotationCFrame().LookVector).Magnitude

                        return (holding and {
                            (turn > 1.66),
                        } or {
                            (turn < 0.77),
                        })[1]
                    end
                end

                return false
            end
            local closestPart = function(character, camera, center, blacklist)
                local best, bestScreen, bestDistance = nil, nil, math.huge

                for _, child in character:GetChildren()do
                    if child:IsA('MeshPart') and not NOT_BODY[child.Name] and not blacklist[child.Name] then
                        local projected = camera:WorldToViewportPoint(child.Position)
                        local screen = Vector2.new(projected.X, projected.Y)
                        local distance = (screen - center).Magnitude

                        if distance < bestDistance then
                            best, bestScreen, bestDistance = child, screen, distance
                        end
                    end
                end

                return best, bestScreen
            end
            local eyes = function(player, fighter, camera)
                local character = player.Character
                local root = (character and {
                    (character:FindFirstChild('HumanoidRootPart')),
                } or {nil})[1]

                if root and root:IsA('BasePart') then
                    return root.Position + Vector3.new(0, (fighter:IsCrouching() and {CROUCHED_EYE} or {EYE})[1], 0)
                end

                return camera.CFrame.Position
            end
            local ignoreCharacters = function(sight)
                local ignored = {}
                local viewModels = Services.Workspace:FindFirstChild('ViewModels')

                if viewModels then
                    table.insert(ignored, viewModels)
                end

                for _, other in Services.Players:GetPlayers()do
                    if other.Character then
                        table.insert(ignored, other.Character)
                    end
                end

                Sight.ignore(sight, ignored)
            end
            local consider = function(
                targeting,
                settings,
                search,
                opponent,
                dueler
            )
                local model = opponent.Character
                local humanoid = (model and {
                    (model:FindFirstChildOfClass('Humanoid')),
                } or {nil})[1]
                local part = (model and {
                    (model:FindFirstChild(search.partName)),
                } or {nil})[1]

                if opponent == targeting.player or type(dueler) ~= 'table' or dueler._is_ally or not model or not humanoid or not (humanoid.Health > 0) or not part or not part:IsA('BasePart') then
                    return nil
                end

                local position = part.Position
                local screen, onScreen = search.camera:WorldToViewportPoint(position)
                local point = Vector2.new(screen.X, screen.Y)
                local away = (point - search.center).Magnitude
                local enemy = dueler.ClientFighter
                local wanted = (not settings.limitDistance or (search.origin - position).Magnitude <= settings.maxDistance) and onScreen and away <= search.radius and type(enemy) == 'table' and not (settings.ignoreProtected and protected(enemy, settings.ignoreIf, search.origin, position))

                if not wanted then
                    return nil
                end

                local hit = part
                local manipulation = nil

                if search.manipulate then
                    local allowed

                    allowed, manipulation = Sight.manipulate(targeting.sight, search.origin, position, model, search.melee)

                    if not allowed then
                        return nil
                    end
                    if manipulation and manipulation.part then
                        hit = manipulation.part
                    end
                elseif settings.visibleOnly and not Sight.clear(targeting.sight, search.origin, position) then
                    return nil
                end

                return {
                    character = model,
                    part = hit,
                    screen = point,
                    humanoid = humanoid,
                    fighter = enemy,
                    manipulation = manipulation,
                    distance = away,
                }
            end
            local selectionOf = function(pick, settings, search)
                local closest, focus = nil, pick.screen

                if (settings.closestPart or settings.aimClosestPart) and not pick.manipulation then
                    closest, focus = closestPart(pick.character, search.camera, search.center, settings.closestBlacklist)
                end

                local silentPart = (settings.closestPart and closest and {closest} or {
                    pick.part,
                })[1]
                local aimPart = (settings.aimClosestPart and closest and {closest} or {
                    pick.part,
                })[1]

                return {
                    silent = pick.distance < search.silentRadius and {
                        part = silentPart,
                        manipulation = pick.manipulation,
                    } or nil,
                    aimbot = pick.distance < search.aimRadius and {
                        part = aimPart,
                        character = pick.character,
                        humanoid = pick.humanoid,
                        fighter = pick.fighter,
                    } or nil,
                    manipulated = search.manipulate,
                    focus = focus,
                }
            end

            function Targeting.new(player, fighters, spectate)
                return {
                    player = player,
                    fighters = fighters,
                    spectate = spectate,
                    sight = Sight.new(),
                    reaction = Reaction.new(),
                    warned = false,
                }
            end

            Targeting.select = function(
                targeting,
                settings,
                camera,
                silentOn,
                aimOn
            )
                local fighter = targeting.fighters.LocalFighter
                local duel = targeting.spectate.CurrentDuelSubject
                local duelers = (type(duel) == 'table' and {
                    duel._duelers_by_player,
                } or {nil})[1]

                if type(fighter) ~= 'table' or type(duelers) ~= 'table' then
                    Reaction.step(targeting.reaction, false, os.clock(), 0, 0, false)

                    return NOTHING
                end

                ignoreCharacters(targeting.sight)

                local item = fighter.EquippedItem
                local manipulate = silentOn and settings.active and settings.manipulation
                local silentRadius = (silentOn and {
                    settings.radius,
                } or {0})[1]
                local aimRadius = (aimOn and {
                    settings.aimRadius,
                } or {0})[1]
                local search = {
                    camera = camera,
                    origin = eyes(targeting.player, fighter, camera),
                    center = camera.ViewportSize / 2,
                    silentRadius = silentRadius,
                    aimRadius = aimRadius,
                    radius = math.max(silentRadius, aimRadius),
                    partName = manipulate and 'HitboxHead' or settings.part,
                    manipulate = manipulate,
                    melee = type(item) == 'table' and type(item.Info) == 'table' and item.Info.Type == 'Melee',
                }
                local picked = nil

                for opponent, dueler in duelers do
                    local checked, pick = pcall(consider, targeting, settings, search, opponent, dueler)

                    if checked then
                        picked = pick or picked
                    elseif not targeting.warned then
                        targeting.warned = true

                        warn(string.format(
[[An opponent could not be checked for aiming; later ones are not reported: %s]], tostring(pick)))
                    end
                end

                local flashed = settings.disableOnFlash and Services.Lighting:FindFirstChild('Flashbang') ~= nil
                local ready = Reaction.step(targeting.reaction, picked ~= nil, os.clock(), settings.reactionTime / 1000, settings.forgetTime, flashed)

                if not ready or not picked then
                    return NOTHING
                end

                return selectionOf(picked, settings, search)
            end

            return table.freeze(Targeting)
        end

        function __ANTIBRAIN_MODULES.r()
            lo... (577 KB left)

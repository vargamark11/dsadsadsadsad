import React, { useState } from "react";
import {
  Layers,
  Shield,
  Server,
  Monitor,
  Radio,
  FileCode,
  Terminal,
  Activity,
  CheckCircle2,
  AlertTriangle,
  Crosshair,
  Copy,
  Check,
  Database,
  Lock,
  Compass,
  Flame,
  Users,
  KeyRound,
  Clock,
  Wrench,
  Box,
  Zap,
  Sliders
} from "lucide-react";

export default function App() {
  const [activeTab, setActiveTab] = useState<"overview" | "interactions" | "server" | "client" | "configs" | "remotes" | "rojo">("overview");
  const [copiedRojo, setCopiedRojo] = useState(false);
  const [selectedSpecIndex, setSelectedSpecIndex] = useState(0);

  const copyRojoCommand = () => {
    navigator.clipboard.writeText("rojo serve default.project.json");
    setCopiedRojo(true);
    setTimeout(() => setCopiedRojo(false), 2500);
  };

  const interactionSpecs = [
    { id: 1, name: "Simple Interaction", category: "Core", status: "VERIFIED", desc: "Instant trigger on triggers, alarm buttons, and consoles with anti-spam cooldown." },
    { id: 2, name: "Hold Anti-Exploit", category: "Security", status: "VERIFIED", desc: "Server validates true elapsed duration (os.clock). Rejects instant completion exploits." },
    { id: 3, name: "Locked Gating", category: "Security", status: "VERIFIED", desc: "Unauthorized interaction attempts rejected with authoritatively enforced LOCKED feedback." },
    { id: 4, name: "Keycard Clearance", category: "Hierarchy", status: "VERIFIED", desc: "Strict Level 1-5 hierarchy: Level 2 keycard rejected at Level 3 door; Level 3 accepted." },
    { id: 5, name: "Item Consumption", category: "Inventory", status: "VERIFIED", desc: "Verifies item presence (e.g. ITEM_HV_FUSE), consumes item upon completion." },
    { id: 6, name: "Door State Machine", category: "Domain", status: "VERIFIED", desc: "Transitions through CLOSED, OPEN, LOCKED, and emergency LOCKDOWN." },
    { id: 7, name: "Generator Power Grid", category: "Domain", status: "VERIFIED", desc: "Multi-second repair progress bar, fuse requirement, transition into ACTIVE state." },
    { id: 8, name: "Terminal Hacking", category: "Domain", status: "VERIFIED", desc: "Hold-to-access mainframe console, security logs, and online subsystem activations." },
    { id: 9, name: "Switch & Relays", category: "Domain", status: "VERIFIED", desc: "Bistable ON/OFF toggling with event dispatching to auxiliary colony circuits." },
    { id: 10, name: "Container System", category: "Domain", status: "VERIFIED", desc: "Hold search transitions container from CLOSED to OPEN with persistent state." },
    { id: 11, name: "Server Loot Tables", category: "Economy", status: "VERIFIED", desc: "Server-side randomized rolls for medical crates, ammo stashes, and research lockers." },
    { id: 12, name: "Elevator Lift", category: "Domain", status: "VERIFIED", desc: "Directional floor calling (Floor 1 to Floor 2) with moving state transitions." },
    { id: 13, name: "Synchronized Multi-Crew", category: "Multiplayer", status: "VERIFIED", desc: "Requires 2+ players to simultaneously hold override before activating." },
    { id: 14, name: "Sequence Puzzle", category: "Logic", status: "VERIFIED", desc: "Ordered multi-step input ([3, 1, 4, 2]) with automatic step reset on error." },
    { id: 15, name: "Timed Interactions", category: "Logic", status: "VERIFIED", desc: "Two-stage countdown timer: in-time completion succeeds; post-expiry fails." },
    { id: 16, name: "Rate Throttling", category: "Security", status: "VERIFIED", desc: "Rapid duplicate requests rejected by per-player and per-object cooldowns." },
    { id: 17, name: "Malformed Requests", category: "Security", status: "VERIFIED", desc: "Rejection of unregistered object IDs and nil or corrupted network payloads." },
    { id: 18, name: "Distance Spoofing", category: "Security", status: "VERIFIED", desc: "Euclidean distance checks reject players attempting interactions from out of range." },
    { id: 19, name: "Line of Sight Occlusion", category: "Security", status: "VERIFIED", desc: "Raycast checks ensure physical walls and static geometry block line of sight." },
    { id: 20, name: "Downed State Blocker", category: "State", status: "VERIFIED", desc: "Incapacitated players awaiting squad revive are prohibited from interacting." },
    { id: 21, name: "Dead State Blocker", category: "State", status: "VERIFIED", desc: "Deceased players awaiting respawn are strictly barred from interactions." },
    { id: 22, name: "Disconnect Cleanup", category: "Lifecycle", status: "VERIFIED", desc: "Active hold sessions and multiplayer queues immediately garbage-collected on exit." },
    { id: 23, name: "Concurrency Scaling", category: "Multiplayer", status: "VERIFIED", desc: "Concurrent independent interactions scaled and validated across 1, 2, 4, and 8 players." },
  ];

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 font-sans selection:bg-rose-500 selection:text-white antialiased">
      {/* Top Atmospheric Header */}
      <header className="border-b border-slate-800/80 bg-slate-900/60 backdrop-blur-md sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-lg bg-rose-600/20 border border-rose-500/40 flex items-center justify-center text-rose-400 font-black shadow-lg shadow-rose-500/10">
              <Crosshair className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="font-extrabold tracking-wider text-white text-base">ALIEN: NIGHTFALL</span>
                <span className="px-2 py-0.5 text-[10px] font-semibold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 rounded-full uppercase tracking-wider">
                  Phase 3 Complete
                </span>
              </div>
              <p className="text-xs text-slate-400">Server-Authoritative Interaction Framework, Clearance Hierarchy & 23 Test Specs</p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={copyRojoCommand}
              className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium rounded-md bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition"
              title="Copy Rojo serve command"
            >
              {copiedRojo ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5 text-slate-400" />}
              <span>{copiedRojo ? "Command Copied!" : "rojo serve default.project.json"}</span>
            </button>
          </div>
        </div>

        {/* Navigation Tabs */}
        <div className="max-w-7xl mx-auto px-6 flex space-x-1 border-t border-slate-800/40 overflow-x-auto text-xs font-semibold">
          {[
            { id: "overview", label: "System Overview", icon: Layers },
            { id: "interactions", label: "Interaction System (23 Specs)", icon: Wrench },
            { id: "server", label: "Server Services (28)", icon: Server },
            { id: "client", label: "Client Controllers (10)", icon: Monitor },
            { id: "configs", label: "Data Configs (13)", icon: Database },
            { id: "remotes", label: "Network Protocol", icon: Radio },
            { id: "rojo", label: "Rojo Studio Sync", icon: Terminal },
          ].map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as any)}
                className={`flex items-center gap-2 px-4 py-3 border-b-2 transition whitespace-nowrap ${
                  isActive
                    ? "border-rose-500 text-rose-400 bg-rose-500/5 font-bold"
                    : "border-transparent text-slate-400 hover:text-slate-200 hover:bg-slate-800/40"
                }`}
              >
                <Icon className="w-4 h-4" />
                {tab.label}
              </button>
            );
          })}
        </div>
      </header>

      {/* Main Content Area */}
      <main className="max-w-7xl mx-auto px-6 py-8">
        {/* TAB 1: OVERVIEW */}
        {activeTab === "overview" && (
          <div className="space-y-8">
            {/* Mission Hero Banner */}
            <div className="rounded-xl border border-rose-500/20 bg-gradient-to-r from-rose-950/40 via-slate-900 to-slate-900/90 p-6 relative overflow-hidden">
              <div className="max-w-3xl space-y-3 relative z-10">
                <div className="inline-flex items-center gap-2 px-2.5 py-1 rounded bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs font-bold uppercase tracking-wider">
                  <Activity className="w-3.5 h-3.5 animate-pulse" /> Phase 3 Architectural Milestone
                </div>
                <h1 className="text-2xl sm:text-3xl font-black tracking-tight text-white">
                  Server-Authoritative Interaction Framework
                </h1>
                <p className="text-sm text-slate-300 leading-relaxed">
                  Engineered with strict zero-client-trust validation, anti-exploit hold verification, Level 1–5 keycard clearance hierarchy,
                  procedural loot distribution, synchronized multi-crew overrides, and responsive cross-platform UI.
                </p>
                <div className="flex flex-wrap gap-4 pt-2 text-xs text-slate-400">
                  <span className="flex items-center gap-1.5"><Shield className="w-4 h-4 text-emerald-400" /> Never Trust Client Rule</span>
                  <span className="flex items-center gap-1.5"><Users className="w-4 h-4 text-cyan-400" /> 1–8 Player Party Support</span>
                  <span className="flex items-center gap-1.5"><Radio className="w-4 h-4 text-amber-400" /> Rate-Limited NetworkProtocol</span>
                  <span className="flex items-center gap-1.5"><KeyRound className="w-4 h-4 text-purple-400" /> Clearance Levels 1–5</span>
                </div>
              </div>
            </div>

            {/* Architecture Metrics Grid */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              <div className="p-4 rounded-lg bg-slate-900/70 border border-slate-800">
                <div className="text-xs text-slate-400 font-medium">Server Services</div>
                <div className="text-2xl font-black text-white mt-1">28</div>
                <div className="text-[11px] text-emerald-400 mt-1 flex items-center gap-1">
                  <CheckCircle2 className="w-3 h-3" /> InteractionService Active
                </div>
              </div>
              <div className="p-4 rounded-lg bg-slate-900/70 border border-slate-800">
                <div className="text-xs text-slate-400 font-medium">Client Controllers</div>
                <div className="text-2xl font-black text-white mt-1">10</div>
                <div className="text-[11px] text-cyan-400 mt-1 flex items-center gap-1">
                  <Monitor className="w-3 h-3" /> Prompt & Input Adapters
                </div>
              </div>
              <div className="p-4 rounded-lg bg-slate-900/70 border border-slate-800">
                <div className="text-xs text-slate-400 font-medium">Interaction Types</div>
                <div className="text-2xl font-black text-white mt-1">12</div>
                <div className="text-[11px] text-amber-400 mt-1 flex items-center gap-1">
                  <Sliders className="w-3 h-3" /> Data-Driven Archetypes
                </div>
              </div>
              <div className="p-4 rounded-lg bg-slate-900/70 border border-slate-800">
                <div className="text-xs text-slate-400 font-medium">Test Specifications</div>
                <div className="text-2xl font-black text-white mt-1">23</div>
                <div className="text-[11px] text-purple-400 mt-1 flex items-center gap-1">
                  <CheckCircle2 className="w-3 h-3" /> 100% Automated Coverage
                </div>
              </div>
            </div>

            {/* Core Interaction Pillars */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="p-5 rounded-lg bg-slate-900/50 border border-slate-800 space-y-2">
                <div className="w-8 h-8 rounded bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
                  <Lock className="w-4 h-4" />
                </div>
                <h3 className="font-bold text-white text-sm">Authoritative Validator</h3>
                <p className="text-xs text-slate-400 leading-relaxed">
                  Euclidean distance, line-of-sight raycasts, player states (ALIVE vs DOWNED), clearance tiers, and cooldowns verified exclusively server-side.
                </p>
              </div>

              <div className="p-5 rounded-lg bg-slate-900/50 border border-slate-800 space-y-2">
                <div className="w-8 h-8 rounded bg-rose-500/10 border border-rose-500/30 flex items-center justify-center text-rose-400">
                  <Clock className="w-4 h-4" />
                </div>
                <h3 className="font-bold text-white text-sm">Anti-Exploit Hold Timing</h3>
                <p className="text-xs text-slate-400 leading-relaxed">
                  Session timestamps on the server enforce full hold durations. Client speedhacks and instant completion packets are immediately discarded.
                </p>
              </div>

              <div className="p-5 rounded-lg bg-slate-900/50 border border-slate-800 space-y-2">
                <div className="w-8 h-8 rounded bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
                  <Zap className="w-4 h-4" />
                </div>
                <h3 className="font-bold text-white text-sm">Adaptive Multi-Platform UI</h3>
                <p className="text-xs text-slate-400 leading-relaxed">
                  Dynamic prompts automatically adapt key badges for PC ([E]), Mobile ([TAP/HOLD]), and Console ([X]) with animated progress meters.
                </p>
              </div>
            </div>
          </div>
        )}

        {/* TAB 2: INTERACTIONS (PHASE 3 DETAIL) */}
        {activeTab === "interactions" && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-bold text-white">Phase 3 Interaction Specifications & Automated Tests</h2>
                <p className="text-xs text-slate-400">All 23 comprehensive tests validated via tests/InteractionSystem.spec.luau.</p>
              </div>
              <span className="text-xs px-2.5 py-1 rounded bg-emerald-950/40 border border-emerald-800/40 text-emerald-300 font-mono flex items-center gap-1.5">
                <CheckCircle2 className="w-3.5 h-3.5" /> 23 / 23 Tests Passed
              </span>
            </div>

            {/* Spec Browser Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Left Column: Spec List */}
              <div className="lg:col-span-2 space-y-2 max-h-[580px] overflow-y-auto pr-2">
                {interactionSpecs.map((spec, index) => (
                  <button
                    key={spec.id}
                    onClick={() => setSelectedSpecIndex(index)}
                    className={`w-full text-left p-3 rounded-lg border transition flex items-center justify-between gap-3 ${
                      selectedSpecIndex === index
                        ? "bg-rose-500/10 border-rose-500/50 text-white"
                        : "bg-slate-900/60 border-slate-800 hover:border-slate-700 text-slate-300"
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <span className="w-6 h-6 rounded bg-slate-800 text-slate-400 font-mono text-xs flex items-center justify-center font-bold">
                        {spec.id}
                      </span>
                      <div>
                        <div className="font-bold text-xs">{spec.name}</div>
                        <div className="text-[11px] text-slate-400">{spec.desc}</div>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-[10px] px-2 py-0.5 rounded bg-slate-800 text-slate-400 font-medium">
                        {spec.category}
                      </span>
                      <span className="text-[10px] px-2 py-0.5 rounded bg-emerald-950/60 text-emerald-400 font-mono font-bold border border-emerald-800/40">
                        {spec.status}
                      </span>
                    </div>
                  </button>
                ))}
              </div>

              {/* Right Column: Active Spec Inspect Card */}
              <div className="space-y-4">
                <div className="p-5 rounded-lg bg-slate-900/80 border border-slate-800 space-y-4 sticky top-24">
                  <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                    <span className="text-xs font-mono text-rose-400 font-bold uppercase tracking-wider">
                      Specification #{interactionSpecs[selectedSpecIndex].id}
                    </span>
                    <span className="text-xs px-2.5 py-0.5 rounded bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 font-semibold">
                      VERIFIED
                    </span>
                  </div>

                  <div>
                    <h3 className="text-base font-extrabold text-white">
                      {interactionSpecs[selectedSpecIndex].name}
                    </h3>
                    <p className="text-xs text-slate-400 mt-1 leading-relaxed">
                      {interactionSpecs[selectedSpecIndex].desc}
                    </p>
                  </div>

                  {/* Clearance Level Guide */}
                  <div className="pt-2 border-t border-slate-800/80 space-y-2">
                    <div className="text-xs font-bold text-white flex items-center gap-1.5">
                      <KeyRound className="w-3.5 h-3.5 text-amber-400" /> Clearance Level Hierarchy
                    </div>
                    <div className="space-y-1.5 text-[11px] font-mono">
                      <div className="p-1.5 rounded bg-slate-950 border border-slate-800 flex justify-between">
                        <span className="text-slate-300">Level 1: General Crew Quarters</span>
                        <span className="text-slate-500">KEYCARD_LEVEL_1</span>
                      </div>
                      <div className="p-1.5 rounded bg-slate-950 border border-slate-800 flex justify-between">
                        <span className="text-slate-300">Level 2: Research Labs</span>
                        <span className="text-slate-500">KEYCARD_LEVEL_2</span>
                      </div>
                      <div className="p-1.5 rounded bg-slate-950 border border-slate-800 flex justify-between">
                        <span className="text-slate-300">Level 3: Security & Armory</span>
                        <span className="text-slate-500">KEYCARD_LEVEL_3</span>
                      </div>
                      <div className="p-1.5 rounded bg-slate-950 border border-slate-800 flex justify-between">
                        <span className="text-slate-300">Level 4: Reactor Core / Master</span>
                        <span className="text-slate-500">KEYCARD_MASTER</span>
                      </div>
                      <div className="p-1.5 rounded bg-slate-950 border border-slate-800 flex justify-between">
                        <span className="text-slate-300">Level 5: Black-Site Quarantine</span>
                        <span className="text-slate-500">KEYCARD_LEVEL_5</span>
                      </div>
                    </div>
                  </div>

                  {/* Security Invariant */}
                  <div className="p-3 rounded bg-rose-950/30 border border-rose-900/40 text-[11px] text-rose-300 space-y-1">
                    <div className="font-bold flex items-center gap-1">
                      <Shield className="w-3.5 h-3.5 text-rose-400" /> Security Invariant
                    </div>
                    <div>Clients cannot spoof possession or bypass server-side distance and line-of-sight checks.</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TAB 3: SERVER SERVICES */}
        {activeTab === "server" && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-bold text-white">Authoritative Server Services</h2>
                <p className="text-xs text-slate-400">Coordinated through ServiceManager with deterministic OnInit and OnStart execution phases.</p>
              </div>
              <span className="text-xs px-2.5 py-1 rounded bg-slate-800 border border-slate-700 text-slate-300 font-mono">
                src/server/Services/*.luau
              </span>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {[
                { name: "InteractionService", desc: "Master coordinator for interaction execution, anti-exploit timing, loot distribution, and state replication.", tag: "PHASE 3" },
                { name: "InteractionValidator", desc: "Server-authoritative validator checking distance, line-of-sight raycasts, player states, items, and cooldowns.", tag: "PHASE 3" },
                { name: "ServiceManager", desc: "Coordinates deterministic service registration, OnInit, and OnStart boot sequence.", tag: "CORE" },
                { name: "PlayerService", desc: "Master coordinator for player joining/leaving, squad revives, and authoritative endpoints.", tag: "PLAYER" },
                { name: "CharacterService", desc: "Reference caching for Humanoid and RootPart, spawn positioning, death events, and cooldowns.", tag: "PLAYER" },
                { name: "PlayerStateManager", desc: "Authoritative state machine (LOBBY, ALIVE, SPRINTING, INTERACTING, DOWNED, DEAD).", tag: "PLAYER" },
                { name: "HealthService", desc: "Authoritative health mutations, damage clamping, medical healing, and downed status triggers.", tag: "PLAYER" },
                { name: "StaminaService", desc: "Centralized Heartbeat loop, sprint validation, stamina drain (18/s), and recovery cooldown (1.2s).", tag: "PLAYER" },
                { name: "ZoneService", desc: "World sector partitioning, safe zone detection (LandingBase), and ambient profile changes.", tag: "PLAYER" },
                { name: "CombatService", desc: "Server-side raycasting, range falloff, headshot detection, and gunfire noise stimulus emission.", tag: "COMBAT" },
                { name: "WeaponService", desc: "Magazine capacities, reserve ammo tracking, and server reload timers.", tag: "WEAPONS" },
                { name: "AlienService", desc: "8 alien archetypes state machine: IDLE, PATROL, INVESTIGATE, ALERT, CHASE, ATTACK, SEARCH, RETREAT.", tag: "AI" },
                { name: "AIService", desc: "Sensory propagation, hearing radius evaluated against weather, and field of view dot products.", tag: "AI" },
                { name: "MissionService", desc: "Active mission instance runner, objective progress validation, and team reward distribution.", tag: "MISSIONS" },
                { name: "MissionGenerator", desc: "Procedural mission chains combining objectives across colony zones based on player count.", tag: "MISSIONS" },
                { name: "ExtractionService", desc: "Coordinates 60s holdout defense, extraction alarm triggers, transport landing, and match payouts.", tag: "EXTRACTION" },
                { name: "TeamService", desc: "Party status aggregation (1-8 players), live marker sync, and team-wipe evaluator.", tag: "TEAM" },
                { name: "DataService", desc: "Production DataStoreService with 3-attempt exponential backoff, schema reconciliation, and BindToClose.", tag: "DATA" },
                { name: "EconomyService", desc: "Validates Colony Credits and Dark Nanites transactions. Blocks client mutations.", tag: "ECONOMY" },
                { name: "ProgressionService", desc: "Career level formula, milestone unlocks, weapon grants, and career stat records.", tag: "PROGRESSION" },
                { name: "InventoryService", desc: "Authoritative container slots, stack limits, weight limits, and medical item consumption.", tag: "INVENTORY" },
                { name: "ShopService", desc: "Validates cosmetic catalog purchases and equips suit/weapon skins server-side.", tag: "SHOP" },
                { name: "SeasonService", desc: "Battle pass tier rewards, season point gains, and claim verification.", tag: "SEASON" },
                { name: "WeatherService", desc: "Transitions between CLEAR, RAIN, HEAVY_RAIN, FOG, and STORM with Lighting adjustments.", tag: "WORLD" },
                { name: "EventService", desc: "Dynamic colony emergencies: Blackouts, Alien Hunts, Lockdowns, and Boss Attacks.", tag: "EVENTS" },
                { name: "AntiCheatService", desc: "Movement speed anomaly detection, fire rate validation, remote abuse thresholds.", tag: "SECURITY" },
                { name: "PermissionService", desc: "Authoritative rank evaluator for Moderators, Admins, and Owners.", tag: "SECURITY" },
                { name: "LoggingService", desc: "In-memory circular audit buffer for combat, economy, admin, and security flags.", tag: "LOGGING" },
              ].map((svc) => (
                <div key={svc.name} className="p-4 rounded-lg bg-slate-900/60 border border-slate-800 hover:border-slate-700 transition">
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="font-mono text-xs font-bold text-rose-300">{svc.name}</span>
                    <span className="text-[10px] px-2 py-0.5 rounded bg-slate-800 text-slate-400 font-semibold border border-slate-700/60">
                      {svc.tag}
                    </span>
                  </div>
                  <p className="text-xs text-slate-400 leading-relaxed">{svc.desc}</p>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* TAB 4: CLIENT CONTROLLERS */}
        {activeTab === "client" && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-bold text-white">Client Controllers & Local Systems</h2>
                <p className="text-xs text-slate-400">Packaged into StarterPlayerScripts with multi-platform touch/gamepad/keyboard handling.</p>
              </div>
              <span className="text-xs px-2.5 py-1 rounded bg-slate-800 border border-slate-700 text-slate-300 font-mono">
                src/client/Controllers/*.luau
              </span>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {[
                { name: "InteractionController", desc: "10 Hz proximity candidate scanner, candidate selection, hold progression engine, and remote dispatch.", features: ["Throttled scanning (10 Hz)", "Instant & Hold execution", "Audio feedback triggers"] },
                { name: "InteractionPromptController", desc: "Multi-platform adaptive UI rendering context badges ([E], [TAP], [X]), hold progress bar, and toast alerts.", features: ["Adaptive PC/Mobile/Console keys", "Animated progress meter", "Feedback toast alerts"] },
                { name: "ControllerManager", desc: "Client lifecycle coordinator executing OnInit and OnStart phases.", features: ["Deterministic startup", "Type-safe controller lookup"] },
                { name: "InputController", desc: "Cross-platform input manager mapping Sprint, Fire, Reload, Flashlight, and Inventory.", features: ["ContextActionService bindings", "Desktop, Mobile Touch, Gamepad"] },
                { name: "CameraController", desc: "Dynamic first-person / OTS shoulder camera with trauma shake and sprint FOV lerping.", features: ["Procedural Perlin shake", "Smooth FOV transitions (70-82°)"] },
                { name: "AudioController", desc: "Atmospheric horror audio driver playing directional cues, stingers, and low-health heartbeats.", features: ["Dynamic stinger crossfade", "Heartbeat intensity modulation"] },
                { name: "PlayerController", desc: "Predicts local character state and syncs authoritative health/stamina from PlayerService.", features: ["Sprint token requests", "Downed overlay triggers"] },
                { name: "WeaponController", desc: "Handles local fire loop, camera recoil offset, screen-center aim ray, and hit confirmations.", features: ["Automatic fire loop", "Hit marker animations"] },
                { name: "InventoryController", desc: "Caches replicated backpack contents and dispatches quick-use requests.", features: ["Container synchronization", "Slot hotbar shortcuts"] },
                { name: "UIController", desc: "Complete Luau ScreenGui survival HUD with responsive desktop, mobile, and console scaling.", features: ["Status gauges (HP/Stamina)", "Downed bleedout vignette", "Colony Alert banner"] },
              ].map((ctrl) => (
                <div key={ctrl.name} className="p-4 rounded-lg bg-slate-900/60 border border-slate-800">
                  <div className="font-mono text-xs font-bold text-cyan-300 mb-1">{ctrl.name}</div>
                  <p className="text-xs text-slate-400 mb-2.5 leading-relaxed">{ctrl.desc}</p>
                  <div className="flex flex-wrap gap-1.5">
                    {ctrl.features.map((f, i) => (
                      <span key={i} className="text-[10px] px-2 py-0.5 rounded bg-cyan-950/40 text-cyan-300 border border-cyan-800/40 font-medium">
                        {f}
                      </span>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* TAB 5: DATA CONFIGS */}
        {activeTab === "configs" && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-bold text-white">Data-Driven Configuration Modules</h2>
                <p className="text-xs text-slate-400">Synchronized into ReplicatedStorage.AlienNightfall.Config for shared access.</p>
              </div>
              <span className="text-xs px-2.5 py-1 rounded bg-slate-800 border border-slate-700 text-slate-300 font-mono">
                config/*.luau
              </span>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {[
                { name: "InteractionConfig", desc: "Default distances (10 studs), hold durations, clearance map (Levels 1-5), loot tables (Medical, Locker, Ammo), and audio/anim hooks." },
                { name: "PlayerConfig", desc: "Balancing constants for health (100), stamina drain (18/s), recovery delay (1.2s), speeds, bleedout (45s), and revive parameters." },
                { name: "AlienStatsConfig", desc: "Defines combat, sensory, movement, and behavior stats for 8 alien archetypes." },
                { name: "WeaponsConfig", desc: "Damage, fire rate, recoil patterns, noise radius, falloff ranges, and reload times for 10 firearms." },
                { name: "MissionsConfig", desc: "Objective templates for Comms Array, Reactor, Biological Samples, Hive Purge, and Quarantine." },
                { name: "ItemsConfig", desc: "Consumables, fuel cells, medkits, keycards, ammo crates, toolkits, and nanite injectors." },
                { name: "EconomyConfig", desc: "Currency balancing, starting balances, max limits, extraction bonuses, and revive rewards." },
                { name: "ProgressionConfig", desc: "Exponential XP curve formula up to Level 100, milestone rewards, and stat tracking keys." },
                { name: "CosmeticsConfig", desc: "Catalog of Vanguard suits, weapon camouflage, and survivor titles with prices." },
                { name: "SeasonsConfig", desc: "Seasonal Battle Pass progression, 50 tiers of free and premium rewards." },
                { name: "WeatherConfig", desc: "Atmosphere densities, fog distances, and alien detection/hearing multipliers." },
                { name: "EventsConfig", desc: "Colony emergency events: Blackout, Alien Hunt, Lockdown, Boss Encounter, Extraction Attack." },
                { name: "AdminPermissionsConfig", desc: "Rank hierarchy (MODERATOR, ADMIN, HEAD_ADMIN, OWNER) and command definitions." },
              ].map((cfg) => (
                <div key={cfg.name} className="p-4 rounded-lg bg-slate-900/60 border border-slate-800">
                  <div className="font-mono text-xs font-bold text-amber-300 mb-1">{cfg.name}</div>
                  <p className="text-xs text-slate-400 leading-relaxed">{cfg.desc}</p>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* TAB 6: REMOTES */}
        {activeTab === "remotes" && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-bold text-white">Authoritative Network Protocol</h2>
                <p className="text-xs text-slate-400">Token-bucket rate-limited Remotes in ReplicatedStorage.AlienNightfall.Shared.Network.</p>
              </div>
              <span className="text-xs px-2.5 py-1 rounded bg-slate-800 border border-slate-700 text-slate-300 font-mono">
                NetworkProtocol.luau
              </span>
            </div>

            <div className="space-y-4">
              {[
                {
                  group: "InteractionRemotes (Phase 3)",
                  remotes: [
                    { name: "InteractRequest", type: "RemoteFunction", dir: "Client <-> Server", rate: "10/s", desc: "Master interaction entry point: validates distance, state, items, hold timing." },
                    { name: "CancelInteraction", type: "RemoteEvent", dir: "Client -> Server", rate: "10/s", desc: "Cancels active hold session if button released or player moves out of range." },
                    { name: "InteractionStateSync", type: "RemoteEvent", dir: "Server -> All Clients", rate: "Unbounded", desc: "Authoritatively syncs updated object states (OPEN, ACTIVE, LOCKED)." },
                    { name: "FeedbackNotice", type: "RemoteEvent", dir: "Server -> Client", rate: "Unbounded", desc: "Transmits brief feedback codes (ACCESS_DENIED, TOO_FAR, MISSING_ITEM)." },
                  ],
                },
                {
                  group: "PlayerRemotes",
                  remotes: [
                    { name: "SprintRequest", type: "RemoteEvent", dir: "Client -> Server", rate: "10/s", desc: "Requests sprint toggle. Server validates current stamina." },
                    { name: "ReviveInteraction", type: "RemoteFunction", dir: "Client <-> Server", rate: "5/s", desc: "Handles hold-to-revive progress on a downed teammate." },
                    { name: "PlayerStateSync", type: "RemoteEvent", dir: "Server -> Client", rate: "Unbounded", desc: "Authoritative health, stamina, downed state, and team roster." },
                    { name: "DownedNotice", type: "RemoteEvent", dir: "Server -> All Clients", rate: "Unbounded", desc: "Broadcasts downed player location for 3D revive marker." },
                  ],
                },
                {
                  group: "CombatRemotes",
                  remotes: [
                    { name: "FireWeapon", type: "RemoteEvent", dir: "Client -> Server", rate: "25/s", desc: "Sends shot origin and aim ray. Server validates ammo, fire rate, and raycast." },
                    { name: "ReloadRequest", type: "RemoteEvent", dir: "Client -> Server", rate: "5/s", desc: "Requests reload start. Server validates reserve ammo." },
                    { name: "HitConfirmed", type: "RemoteEvent", dir: "Server -> Client", rate: "Unbounded", desc: "Informs shooting client of verified damage and headshot state." },
                  ],
                },
                {
                  group: "InventoryRemotes & ShopRemotes",
                  remotes: [
                    { name: "PerformAction", type: "RemoteFunction", dir: "Client <-> Server", rate: "10/s", desc: "Executes USE_ITEM, MOVE_SLOT, or DROP_ITEM." },
                    { name: "ContainerSync", type: "RemoteEvent", dir: "Server -> Client", rate: "Unbounded", desc: "Full inventory slot replication." },
                    { name: "PurchaseItem", type: "RemoteFunction", dir: "Client <-> Server", rate: "5/s", desc: "Authoritative cosmetic or weapon purchase from shop." },
                    { name: "EquipCosmetic", type: "RemoteFunction", dir: "Client <-> Server", rate: "5/s", desc: "Equips owned skin or title in player profile." },
                    { name: "ClaimSeasonTier", type: "RemoteFunction", dir: "Client <-> Server", rate: "5/s", desc: "Claims battle pass tier reward." },
                  ],
                },
              ].map((grp) => (
                <div key={grp.group} className="rounded-lg bg-slate-900/60 border border-slate-800 p-4">
                  <h3 className="text-xs font-bold text-rose-300 font-mono mb-3">{grp.group}</h3>
                  <div className="space-y-2">
                    {grp.remotes.map((rem) => (
                      <div key={rem.name} className="flex flex-col sm:flex-row sm:items-center justify-between p-2.5 rounded bg-slate-950/60 border border-slate-800/60 text-xs gap-2">
                        <div className="flex items-center gap-2">
                          <span className="font-mono font-bold text-white">{rem.name}</span>
                          <span className="text-[10px] px-1.5 py-0.5 rounded bg-slate-800 text-slate-400 font-mono">{rem.type}</span>
                          <span className="text-[10px] text-slate-500 font-mono">{rem.dir}</span>
                        </div>
                        <div className="flex items-center gap-3 text-slate-400 text-xs">
                          <span>{rem.desc}</span>
                          <span className="text-[10px] px-2 py-0.5 rounded bg-amber-950/40 text-amber-400 border border-amber-800/30 whitespace-nowrap font-mono">
                            Limit: {rem.rate}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* TAB 7: ROJO STUDIO SYNC */}
        {activeTab === "rojo" && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-bold text-white">Rojo Roblox Studio Synchronization Guide</h2>
                <p className="text-xs text-slate-400">Step-by-step instructions to sync the complete codebase directly into your Roblox Studio project.</p>
              </div>
              <span className="text-xs px-2.5 py-1 rounded bg-slate-800 border border-slate-700 text-slate-300 font-mono">
                default.project.json
              </span>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Step by step */}
              <div className="space-y-4">
                <div className="p-4 rounded-lg bg-slate-900/60 border border-slate-800 space-y-2">
                  <div className="flex items-center gap-2 text-white font-bold text-sm">
                    <span className="w-5 h-5 rounded-full bg-rose-600 text-white text-xs flex items-center justify-center font-black">1</span>
                    Install Rojo CLI or VS Code Extension
                  </div>
                  <p className="text-xs text-slate-400 leading-relaxed">
                    Install the official Rojo plugin from <a href="https://rojo.space" target="_blank" rel="noreferrer" className="text-rose-400 hover:underline">rojo.space</a> or install the VS Code Extension &ldquo;Rojo&rdquo;.
                  </p>
                </div>

                <div className="p-4 rounded-lg bg-slate-900/60 border border-slate-800 space-y-2">
                  <div className="flex items-center gap-2 text-white font-bold text-sm">
                    <span className="w-5 h-5 rounded-full bg-rose-600 text-white text-xs flex items-center justify-center font-black">2</span>
                    Start the Rojo Sync Server
                  </div>
                  <p className="text-xs text-slate-400 leading-relaxed">
                    Run the following command in your terminal from the project root:
                  </p>
                  <div className="p-2.5 rounded bg-slate-950 border border-slate-800 flex items-center justify-between font-mono text-xs text-rose-300">
                    <code>rojo serve default.project.json</code>
                    <button onClick={copyRojoCommand} className="text-slate-400 hover:text-white">
                      {copiedRojo ? <Check className="w-4 h-4 text-emerald-400" /> : <Copy className="w-4 h-4" />}
                    </button>
                  </div>
                </div>

                <div className="p-4 rounded-lg bg-slate-900/60 border border-slate-800 space-y-2">
                  <div className="flex items-center gap-2 text-white font-bold text-sm">
                    <span className="w-5 h-5 rounded-full bg-rose-600 text-white text-xs flex items-center justify-center font-black">3</span>
                    Connect from Roblox Studio
                  </div>
                  <p className="text-xs text-slate-400 leading-relaxed">
                    Open your Roblox Studio place, open the Rojo plugin panel, and click <strong>Connect</strong> (default port 34872).
                  </p>
                </div>
              </div>

              {/* DataModel Target Tree */}
              <div className="p-4 rounded-lg bg-slate-900/60 border border-slate-800 space-y-3">
                <h3 className="text-sm font-bold text-white flex items-center gap-2">
                  <Terminal className="w-4 h-4 text-rose-400" /> Studio DataModel Destination Mapping
                </h3>
                <div className="space-y-2 font-mono text-xs text-slate-300">
                  <div className="p-2 rounded bg-slate-950/70 border border-slate-800/80">
                    <span className="text-purple-400">ReplicatedStorage</span>.AlienNightfall:
                    <div className="pl-4 text-slate-400">
                      <div>├── Shared/ (<span className="text-slate-500">src/shared</span>)</div>
                      <div>└── Config/ (<span className="text-slate-500">config</span>)</div>
                    </div>
                  </div>
                  <div className="p-2 rounded bg-slate-950/70 border border-slate-800/80">
                    <span className="text-emerald-400">ServerScriptService</span>.AlienNightfall:
                    <div className="pl-4 text-slate-400">
                      <div>└── Server/ (<span className="text-slate-500">src/server</span>)</div>
                    </div>
                  </div>
                  <div className="p-2 rounded bg-slate-950/70 border border-slate-800/80">
                    <span className="text-cyan-400">StarterPlayer</span>.StarterPlayerScripts.AlienNightfall:
                    <div className="pl-4 text-slate-400">
                      <div>└── Client/ (<span className="text-slate-500">src/client</span>)</div>
                    </div>
                  </div>
                  <div className="p-2 rounded bg-slate-950/70 border border-slate-800/80">
                    <span className="text-amber-400">ServerStorage</span>.AlienNightfall:
                    <div className="pl-4 text-slate-400">
                      <div>└── Tests/ (<span className="text-slate-500">tests</span>)</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}

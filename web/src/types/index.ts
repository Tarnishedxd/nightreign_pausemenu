/**
 * @author laot
 * @github https://github.com/laot7490
 * @created 2026-05-21
 */

export type Page = "pause" | "map" | "gtaMap" | "settings" | "stats";

export type StatSkillId =
	| "stamina"
	| "shooting"
	| "strength"
	| "stealth"
	| "flying"
	| "driving"
	| "lung";

export type StatSkill = {
	id: StatSkillId;
	value: number;
};

export type StatCareer = {
	session: number;
	played: number;
	deaths: number;
	onFoot: number;
	driven: number;
};

export type StatsPayload = {
	skills: StatSkill[];
	career: StatCareer;
};

export type LocaleStore = {
	locale: string;
	translations: Record<string, string>;
};

export type MapInfoState = {
	zone: string;
	street: string;
	altitude: number;
};

export type SettingsCategory = {
	id: string;
	index: number;
	label: string;
	pending: number;
};

export type SettingKind = "options" | "slider" | "cycled" | "locked" | "info" | "button" | "spacer";

export type GameSettingRow = {
	type: "setting";
	id: string;
	index: number;
	uniqueId?: number;
	label: string;
	value: string;
	kind: SettingKind;
	editable: boolean;
	selectedIndex: number;
	maxIndex: number;
	choices: string[];
	step?: number;
	pending?: boolean;
};

export type KeyBindingGroup = {
	id: string;
	label: string;
	index: number;
	button?: boolean;
};

export type KeyBindingRow = {
	type: "keybind";
	id: string;
	index: number;
	groupId: string;
	action: string;
	resource: string;
	primary: string;
	secondary: string;
	editable: boolean;
	command: string;
};

export type SettingsRow = GameSettingRow | KeyBindingRow;

export type SettingsState = {
	status: "idle" | "loading" | "ready" | "error";
	build: string;
	error: string;
	categories: SettingsCategory[];
	activeCategoryId: string;
	rows: SettingsRow[];
	version: number;
	busy: boolean;
	keyBindings: boolean;
	keyGroups: KeyBindingGroup[];
	activeKeyGroupId: string;
	listenIndex: number;
	listenSlot: "" | "primary" | "secondary";
	listenPhase: "" | "wait" | "press";
	keyPrompt: boolean;
	vram: string;
	vramPercent: number;
	pendingCount: number;
	veil: boolean;
};

export type GtaAlertButton = {
	label: string;
	control: number;
};

export type GtaAlertState = {
	open: boolean;
	title: string;
	body: string;
	prompt: string;
	detail: string;
	buttons: GtaAlertButton[];
};

export type SettingsStore = {
	settings: SettingsState;
	alert: GtaAlertState;
};

export type MainStore = {
	visible: boolean;
	currentPage: Page;
	quitConfirm: boolean;
	player: Player;
	map: MapInfoState;
};

export type Player = {
	source: number;
	name: string;
	serverName: string;
	cash: number;
	bank: number;
	players: number;
	maxPlayers: number;
	currency: string;
	currencyFormat: string;
	enable3DMap: boolean;
	showBranding: boolean;
};

export type MarkerGroup = {
	id: string;
	label: string;
};

export type MarkerShare = {
	name: string;
	identifier: string;
};

export type MarkerPoint = {
	id: string;
	group: string;
	category?: string;
	label: string;
	sprite: string;
	owned: boolean;
	global?: boolean;
	canDelete?: boolean;
	db?: number;
	showOn2d?: boolean;
	spriteId?: number;
	blipColour?: number;
	scale?: number;
	shortRange?: boolean;
	shares: MarkerShare[];
	from?: string;
	sharedAt?: number;
	metres: number;
};

export type MarkerRequest = {
	id: number;
	label: string;
	sprite: string;
	blipColour?: number;
	from: string;
};

export type MarkerDraft = {
	x: number;
	y: number;
	z: number;
};

export type GlobalCategory = {
	id: string;
	label: string;
};

export type MarkerSheet = {
	groups: MarkerGroup[];
	points: MarkerPoint[];
	requests: MarkerRequest[];
	placing: boolean;
	draft: false | MarkerDraft;
	playerCreator?: boolean;
	adminCreator?: boolean;
	isAdmin?: boolean;
	placingMode?: false | "personal" | "global";
	globalCategories?: GlobalCategory[];
};

export type MarkerNoticeKind = "success" | "error";

export type MarkersStore = {
	sheet: MarkerSheet;
	notice: string;
	noticeKind: MarkerNoticeKind;
	selected: string | null;
	searchHits: string[] | null;
};

export type LegendKind = "blip" | "player" | "waypoint";

export type LegendRow = {
	id: string;
	index: number;
	label: string;
	sprite: string;
	colour: string;
	count: number;
	isNew: boolean;
	fixed: boolean;
	kind: LegendKind;
	group: string;
	cycle: number;
};

export type LegendGroup = {
	id: string;
	label: string;
	order: number;
};

export type LegendToast = {
	token: number;
	kind: "" | "set" | "removed" | "none";
	label: string;
	cycle: number;
	count: number;
};

export type LegendStatus = "idle" | "loading" | "ready" | "fallback";

export type LegendState = {
	status: LegendStatus;
	rows: LegendRow[];
	groups: LegendGroup[];
	toast: LegendToast;
	focus: number;
};

export type LegendStore = {
	legend: LegendState;
};

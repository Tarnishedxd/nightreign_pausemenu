const skillOrder: StatSkillId[] = [
	"stamina",
	"shooting",
	"strength",
	"stealth",
	"flying",
	"driving",
	"lung",
];

const payload = ref<StatsPayload | null>(null);
let requestId = 0;

const clampSkill = (value: unknown) => {
	const amount = Math.round(Number(value) || 0);
	return Math.min(100, Math.max(0, amount));
};

const normalizeStats = (raw: Partial<StatsPayload> | null | undefined): StatsPayload => {
	const byId = new Map((raw?.skills ?? []).map((skill) => [skill.id, skill.value]));
	const career = raw?.career ?? ({} as Partial<StatCareer>);
	return {
		skills: skillOrder.map((id) => ({ id, value: clampSkill(byId.get(id)) })),
		career: {
			session: Math.max(0, Number(career.session) || 0),
			played: Math.max(0, Number(career.played) || 0),
			deaths: Math.max(0, Math.round(Number(career.deaths) || 0)),
			onFoot: Math.max(0, Number(career.onFoot) || 0),
			driven: Math.max(0, Number(career.driven) || 0),
		},
	};
};

export const useStats = () => {
	const begin = () => {
		requestId += 1;
		payload.value = null;
		return requestId;
	};

	const accept = (id: number, data: Partial<StatsPayload> | null | undefined) => {
		if (id !== requestId) return;
		payload.value = normalizeStats(data);
	};

	return { payload, begin, accept };
};

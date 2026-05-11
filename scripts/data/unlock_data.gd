extends Resource
class_name UnlockData

## UnlockData — defines hero and card unlock conditions.

# Hero unlock definitions
# Cost in spirit_points.
const HERO_UNLOCKS := {
	# SHU
	"liu_bei": {"cost": 200, "desc_zh": "擁有任意隨從通關"},
	"guan_yu": {"cost": 100, "desc_zh": "使用趙雲通關區域 1"},
	"zhang_fei": {"cost": 100, "desc_zh": "使用關羽通關區域 1"},
	"zhuge_liang": {"cost": 200, "desc_zh": "累積通關 5 次"},
	"zhao_yun": {"cost": 0, "desc_zh": "初始英雄"},
	"ma_chao": {"cost": 100, "desc_zh": "使用騎兵裝備通關"},
	"huang_zhong": {"cost": 100, "desc_zh": "使用「殺」造成累積 50 點傷害"},
	"huang_yueying": {"cost": 200, "desc_zh": "使用錦囊牌累積 15 次"},
	# WEI
	"cao_cao": {"cost": 0, "desc_zh": "初始英雄"},
	"sim_yi": {"cost": 200, "desc_zh": "通關區域 2"},
	"xiahou_dun": {"cost": 100, "desc_zh": "累積承受 30 點傷害"},
	"zhen_ji": {"cost": 200, "desc_zh": "使用判定相關效果 10 次"},
	"guo_jia": {"cost": 200, "desc_zh": "使用錦囊牌 20 次"},
	"xiahou_yuan": {"cost": 100, "desc_zh": "使用「殺」一回合內擊敗 2 名敵方"},
	"xu_chu": {"cost": 200, "desc_zh": "使用裸衣技能造成累積 20 點傷害"},
	# WU
	"sun_quan": {"cost": 0, "desc_zh": "初始英雄"},
	"zhou_yu": {"cost": 200, "desc_zh": "使用「決鬥」擊敗 5 名敵方"},
	"lu_xun": {"cost": 200, "desc_zh": "通關區域 3"},
	"huang_gai": {"cost": 100, "desc_zh": "使用「酒」強化後的「殺」擊敗敵方 5 次"},
	"da_qiao": {"cost": 200, "desc_zh": "使用「樂不思蜀」5 次"},
	"lv_meng": {"cost": 200, "desc_zh": "單場手牌為 0 的情況下通關"},
	"gan_ning": {"cost": 200, "desc_zh": "使用奇襲技能擊敗 5 名敵方"},
	"xiao_qiao": {"cost": 200, "desc_zh": "使用天香技能成功否定傷害 10 次"},
	# QUN
	"lv_bu": {"cost": 300, "desc_zh": "通關區域 2 首領（呂布）"},
	"diao_chan": {"cost": 200, "desc_zh": "使用「決鬥」累積 10 次"},
	"zhang_jiao": {"cost": 200, "desc_zh": "使用雷擊技能造成累積 30 點傷害"},
}

static func get_cost(hero_id: String) -> int:
	return HERO_UNLOCKS.get(hero_id, {}).get("cost", 100)

static func get_desc(hero_id: String) -> String:
	return HERO_UNLOCKS.get(hero_id, {}).get("desc_zh", "?")

func is_starter(hero_id: String) -> bool:
	return hero_id in ["zhao_yun", "cao_cao", "sun_quan"]
extends RefCounted
## Disclosed, duplicate-free cosmetic draws. A tier is rolled first, then a
## uniformly selected unowned skin in that tier. Empty tiers are removed.
const Rarity=preload("res://fidelity/skin_rarity.gd")
const GUARANTEES:={"epic":5,"legendary":10,"prismatic":20}

static func clean_counters(value:Dictionary)->Dictionary:
	var result:Dictionary={}
	for tier in GUARANTEES:
		result[tier]=clampi(int(value.get(tier,0)),0,int(GUARANTEES[tier])-1)
	return result

static func offer(catalog:Array[Dictionary],owned:Array[String],group:String,counters:Dictionary)->Dictionary:
	var pools:Array[Array]=[[],[],[],[],[],[]]
	for definition in catalog:
		if (definition.group!=group and group!="collection") or owned.has(definition.id):continue
		var rank:=Rarity.index_of(str(definition.rarity))
		if rank>=0:pools[rank].append(str(definition.id))
	var safe:=clean_counters(counters)
	var floor_rank:=0
	var guarantee:=""
	for tier in GUARANTEES:
		var rank:=Rarity.index_of(tier)
		var available:=false
		for index in range(rank,pools.size()):
			available=available or not pools[index].is_empty()
		if available and int(safe[tier])>=int(GUARANTEES[tier])-1 and rank>floor_rank:
			floor_rank=rank;guarantee=tier
	var total:=0
	var entries:Array[Dictionary]=[]
	for rank in Rarity.ORDER.size():
		var weight:=Rarity.BASE_WEIGHTS[rank] if rank>=floor_rank and not pools[rank].is_empty() else 0
		total+=weight
		entries.append({"rarity":Rarity.ORDER[rank],"weight":weight,"ids":pools[rank],"chance":0.0})
	for entry in entries:
		entry.chance=float(entry.weight)/float(total) if total>0 else 0.0
	return {"entries":entries,"total_weight":total,"guarantee":guarantee,"counters":safe}

static func choose(disclosed_offer:Dictionary,tier_roll:float,item_roll:float)->String:
	var total:=int(disclosed_offer.get("total_weight",0))
	if total<=0:return ""
	var position:=clampf(tier_roll,0.0,.999999999)*float(total)
	for entry:Dictionary in disclosed_offer.entries:
		if int(entry.weight)<=0:continue
		if position<float(entry.weight):
			var ids:Array=entry.ids
			return str(ids[mini(ids.size()-1,int(clampf(item_roll,0.0,.999999999)*ids.size()))])
		position-=float(entry.weight)
	return ""

static func advance(counters:Dictionary,awarded_rarity:String)->Dictionary:
	var result:=clean_counters(counters)
	var awarded_rank:=Rarity.index_of(awarded_rarity)
	for tier in GUARANTEES:
		result[tier]=0 if awarded_rank>=Rarity.index_of(tier) else mini(int(GUARANTEES[tier])-1,int(result[tier])+1)
	return result

"""Author a deterministic 100-type city kit, shared by Godot and Houdini.

Types are functional silhouettes, not recolors or separately counted instances.
No DCC, network access or background worker is required to author the recipes.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DISTRICTS = [
    ("night_market", "Night Market", (1, 26), "ed895d"),
    ("maker_yard", "Maker Yard", (-59, 28), "e6b35c"),
    ("canal_works", "Canal Works", (-59, -1), "58bec4"),
    ("observatory", "Observatory", (-59, -30), "a992eb"),
    ("greenhouse", "Glass Gardens", (-29, -60), "8dbd73"),
    ("transit", "Transit Exchange", (1, -60), "729bd9"),
    ("festival", "Lantern Fair", (31, -60), "e88ba9"),
    ("energy", "Energy Commons", (59, -27), "6dccbc"),
    ("skyport", "Parcel Skyport", (59, 3), "e7b873"),
    ("sculpture", "Kinetic Garden", (59, 33), "b3a7dd"),
]


class Recipe:
    def __init__(self, name, district):
        self.name, self.district, self.parts = name, district, []
        self.object_id = "frame"

    def object(self, object_id="frame"):
        """Declare physical ownership, independent of mesh/material batching."""
        self.object_id = object_id
        return self

    def part(self, shape, xyz, size, tone="body", motion="none", rotation=(0, 0, 0)):
        self.parts.append(dict(shape=shape, position=list(xyz), size=list(size),
                               tone=tone, motion=motion, rotation=list(rotation),
                               object_id=self.object_id))
        return self

    def box(self, xyz, size, tone="body", motion="none", rotation=(0, 0, 0)):
        return self.part("box", xyz, size, tone, motion, rotation)

    def tube(self, xyz, size, tone="metal", motion="none", rotation=(0, 0, 0)):
        return self.part("cylinder", xyz, size, tone, motion, rotation)

    def ball(self, xyz, size, tone="accent", motion="none"):
        return self.part("sphere", xyz, size, tone, motion)

    def cone(self, xyz, size, tone="accent", motion="none"):
        return self.part("cone", xyz, size, tone, motion)

    def legs(self, width=.95, depth=.6, height=.8):
        for x in (-width/2, width/2):
            for z in (-depth/2, depth/2):
                self.box((x, height/2, z), (.09, height, .09), "metal")
        return self

    def table(self, width=1.25, depth=.8, height=.85):
        self.legs(width*.8, depth*.8, height)
        return self.box((0, height, 0), (width, .12, depth), "wood")

    def wheel(self, xyz, radius=.19):
        return self.tube(xyz, (radius*2, .12, radius*2), "dark", rotation=(90, 0, 0))

    def canopy(self, width=1.6, depth=1, height=1.9):
        for x in (-width*.45, width*.45):
            self.box((x, height/2, -.32), (.07, height, .07), "metal")
        return self.box((0, height, 0), (width, .12, depth), "accent")


def author():
    kit = []
    def new(name, district):
        r = Recipe(name, district); kit.append(r); return r

    # Each call below describes a separate usable object, with its own structure.
    r = new("Espresso Cart", 0).table().canopy()
    r.box((0,1.15,0),(.65,.5,.45)).tube((.4,1.12,.1),(.16,.27,.16),"light")
    r.tube((-.25,1.47,0),(.24,.16,.24),"accent","steam")
    r = new("Bread Oven",0).box((0,.6,0),(1.1,1.2,.9),"brick")
    r.box((0,.75,.46),(.65,.4,.05),"dark").tube((.3,1.5,-.25),(.23,.65,.23))
    r.box((0,.72,.5),(.44,.14,.06),"accent","glow")
    r = new("Fish Counter",0).table(1.7,1,.7).box((0,.88,0),(1.6,.18,.9),"light")
    for i,x in enumerate((-.55,0,.55)):r.object(f"fish_{i}").ball((x,1.04,0),(.2,.12,.62),"accent")
    r = new("Fruit Stand",0).table().canopy(1.6,1,2)
    for x in (-.4,0,.4):
        for z in (-.2,.2):r.object(f"fruit_{x}_{z}").ball((x,1.04,z),(.25,.25,.25),"accent")
    r = new("Flower Bar",0).table(1.4,.7,.65)
    for x in (-.5,0,.5):
        r.object(f"flower_{x}").cone((x,.88,0),(.27,.4,.27),"brick").tube((x,1.2,0),(.035,.4,.035),"leaf")
        r.ball((x,1.44,0),(.36,.24,.36),"accent","sway")
    r = new("Noodle Booth",0).table(1.6,1).canopy(1.85,1.25,2.25)
    r.box((.46,1.35,0),(.38,.92,.5))
    r.object("noodle_bowl").tube((-.3,1.06,0),(.52,.3,.52),"light")
    r.box((-.25,1.23,0),(.42,.05,.04),"wood","sway")
    r = new("Market Balance",0).table(.95,.65,.6)
    r.box((0,1,0),(.09,.75,.09)).box((0,1.37,0),(.85,.05,.07),"accent","rock")
    for x in (-.36,.36):r.tube((x,1.15,0),(.32,.06,.32),"light")
    r = new("Juice Press",0).table(.85,.75)
    r.tube((0,1.12,0),(.36,.5,.36),"light").box((0,1.55,0),(.55,.08,.18),"metal","pump")
    r.box((.3,1.28,0),(.07,.6,.08)).ball((.33,1.67,0),(.14,.14,.14))
    r = new("Pretzel Rack",0).legs(1,.6,1.65)
    for y in (.55,1,1.45):
        r.object().box((0,y,0),(1.1,.07,.55),"wood")
        for x in (-.3,.3):r.object(f"pretzel_{x}_{y}").tube((x,y+.2,0),(.32,.15,.32),"bread",rotation=(90,0,0))
    r = new("Street Grill",0).table(1.5,.8,.65)
    r.box((0,.92,0),(1.35,.43,.7),"dark")
    for x in (-.45,-.15,.15,.45):r.box((x,1.16,0),(.045,.03,.6),"metal")
    r.ball((0,1.5,0),(.3,.5,.3),"light","steam")

    r = new("Laser Cutter",1).table(1.5,1)
    r.box((0,1.3,-.42),(1.4,.8,.12)).box((0,1.63,0),(1.4,.08,.85))
    r.box((0,1.4,0),(.2,.3,.24),"accent","slide")
    r = new("Print Farm",1).table(1.4,.8)
    for x in (-.43,.43):
        r.box((x,1.35,0),(.07,1,.6)).box((x,1.85,0),(.4,.08,.6))
    r.box((0,1.6,0),(.18,.12,.2),"metal","slide")
    r.object("printed_part").cone((0,1.14,0),(.45,.45,.45),"accent")
    r = new("Precision Lathe",1).table(1.7,.75)
    r.box((-.64,1.12,0),(.32,.5,.5)).tube((.02,1.17,0),(.3,1,.3),"accent","spin_x",(0,0,90))
    r = new("Drill Press",1).box((0,.15,0),(.8,.3,.75))
    r.box((0,1,-.25),(.16,1.8,.18)).box((0,1.7,0),(.55,.4,.65))
    r.tube((0,1.22,.23),(.07,.65,.07),"metal","pump")
    r = new("Welding Bench",1).table(1.5,.9)
    r.object("workpiece").box((0,1.14,0),(.5,.44,.4),"metal").ball((.2,1.36,.12),(.09,.09,.09),"light","glow")
    r.object("welder").box((-.6,.4,-.2),(.28,.65,.3),"accent")
    r = new("Assembly Arm",1).tube((0,.18,0),(.72,.36,.72))
    r.box((0,.8,0),(.2,1,.2),"accent",rotation=(0,0,-25))
    r.box((.42,1.4,0),(.9,.16,.2),"metal","rock").box((.85,1.18,0),(.22,.4,.3),"dark")
    r = new("Roller Conveyor",1).legs(1.6,.65,.65)
    for x in (-.7,-.35,0,.35,.7):r.tube((x,.7,0),(.2,.78,.2),"metal","spin_z",(90,0,0))
    r.object("parcel").box((0,1,0),(.45,.4,.4),"wood","slide")
    r = new("Solder Station",1).table(1.1,.85)
    r.object("station").box((-.25,1.04,0),(.4,.25,.42),"accent")
    r.object("circuit_board").box((.32,.95,0),(.36,.08,.45),"leaf")
    r.object("iron").tube((.3,1.16,0),(.05,.45,.05),"metal",rotation=(0,0,30))
    r = new("Tool Chest",1).box((0,.65,0),(1.1,1,.65))
    for y in (.35,.62,.9):r.box((0,y,.34),(.9,.04,.05),"light")
    for x in (-.4,.4):r.wheel((x,.15,0),.15)
    r = new("Workshop Gantry",1).legs(1.5,.55,2.3)
    r.box((0,2.3,0),(1.7,.18,.7)).box((0,2.02,0),(.32,.42,.3),"accent","slide")

    r = new("Lock Wheel",2).box((0,.3,0),(.7,.6,.65),"brick")
    r.tube((0,.9,0),(.06,.8,.06)).box((0,1.3,0),(.9,.06,.09),"accent","spin_y")
    r = new("Mooring Bollard",2).tube((0,.3,0),(.42,.6,.42))
    r.box((0,.53,0),(.9,.12,.2),"accent").tube((0,.04,0),(.75,.08,.75),"dark")
    r = new("Canal Lift Bridge",2).legs(1.6,.85,1.4)
    r.box((0,.48,0),(1.9,.13,.95),"wood","rock").box((0,1.4,0),(1.8,.1,.1))
    r = new("Waterwheel",2).legs(.6,.7,1.05)
    r.tube((0,1,0),(1.5,.3,1.5),"wood","spin_z",(90,0,0))
    for x in (-.64,.64):r.box((x,1,0),(.14,1,.45),"accent")
    r = new("Canal Pump",2).tube((0,.65,0),(.5,1.3,.5))
    r.box((.4,1.28,0),(.9,.1,.12),"accent","rock").tube((.38,.37,0),(.2,.7,.2))
    r = new("Navigation Buoy",2).cone((0,.4,0),(.8,.8,.8))
    r.tube((0,1,0),(.1,.55,.1)).ball((0,1.36,0),(.23,.23,.23),"accent","glow")
    r = new("Sluice Gate",2).legs(1.2,.5,1.8)
    r.box((0,.85,0),(1.12,1.4,.13),"accent","pump").box((0,1.88,0),(1.5,.12,.2))
    r = new("Cargo Crane",2).tube((0,1.1,0),(.24,2.2,.24))
    r.box((.52,2.18,0),(1.5,.12,.2),"accent","sweep").box((1,1.38,0),(.05,1.5,.05))
    r = new("Survey Skiff",2).box((0,.26,0),(.8,.32,1.7),"wood")
    r.cone((0,.38,-.7),(.8,.25,.7)).box((0,.65,0),(.5,.5,.7),"light")
    r = new("Tow Winch",2).table(.95,.75,.45)
    r.tube((0,.77,0),(.6,.7,.6),"accent","spin_x",(0,0,90)).box((.44,.76,0),(.12,.7,.6))

    r = new("Reflector Telescope",3).legs(1,.8,1)
    r.tube((0,1.5,0),(.5,1.45,.5),"light","sweep",(55,0,0))
    r = new("Radio Dish",3).tube((0,.7,0),(.19,1.4,.19))
    r.cone((0,1.65,0),(1.4,.38,1.4),"light","sweep").tube((0,1.94,0),(.07,.5,.07),"accent")
    r = new("Solar Orrery",3).tube((0,.5,0),(.25,1,.25))
    r.ball((0,1.2,0),(.45,.45,.45),"accent").box((0,1.2,0),(1.6,.06,.06),"metal","spin_y")
    r.ball((.78,1.2,0),(.2,.2,.2),"light","bob")
    r = new("Gyroscope",3).box((0,.15,0),(.9,.3,.8))
    r.tube((0,.9,0),(1,.15,1),"accent","spin_z",(90,0,0))
    r.box((0,.9,0),(.08,1.15,.08),"light","rock")
    r = new("Meteor Cabinet",3).box((0,.4,0),(.95,.8,.8))
    r.box((0,.85,.36),(.55,.08,.24),"light")
    r.object("meteor").ball((0,1.08,0),(.7,.5,.58),"stone","spin_y")
    r = new("Telemetry Mast",3).tube((0,1.2,0),(.14,2.4,.14))
    for y in (.8,1.5,2.2):r.box((0,y,0),(1.1,.055,.06),"accent")
    r.ball((0,2.5,0),(.16,.16,.16),"light","glow")
    r = new("Prism Tower",3).box((0,.25,0),(.65,.5,.65))
    for y in (.8,1.35,1.9):r.object(f"prism_{y}").cone((0,y,0),(.65,.55,.65),"accent","spin_y")
    r = new("Weather Balloon",3).box((0,.15,0),(.48,.3,.42),"wood")
    r.tube((0,.95,0),(.025,1.7,.025),"light").ball((0,2.1,0),(1,.95,1),"accent","bob")
    r = new("Interferometer",3).table(1.5,1,.7)
    for x in (-.55,.55):r.box((x,1.13,0),(.17,.75,.4),"light",rotation=(0,30,0))
    r.box((0,1.1,0),(1.3,.04,.04),"accent","glow")
    r = new("Star Projector",3).tube((0,.3,0),(.68,.6,.68))
    r.ball((0,.95,0),(.8,.8,.8),"dark","spin_y")
    for x in (-.23,.23):r.ball((x,1,.36),(.12,.12,.12),"light","glow")

    r = new("Hydroponic Rack",4).legs(1.4,.75,1.7)
    for y in (.55,1.1,1.65):
        r.object().box((0,y,0),(1.55,.15,.8),"light")
        for x in (-.5,0,.5):r.object(f"plant_{x}_{y}").cone((x,y+.26,0),(.27,.34,.27),"leaf")
    r = new("Seed Sorter",4).table(1.1,.85)
    r.cone((0,1.33,0),(.7,.75,.7),"light").box((0,.96,.48),(.4,.09,.6),"accent","slide")
    r = new("Compost Tumbler",4).legs(.95,.75,.8)
    r.tube((0,.9,0),(.85,1.2,.85),"leaf","spin_x",(0,0,90))
    r = new("Irrigation Fan",4).tube((0,.65,0),(.12,1.3,.12))
    r.box((0,1.35,0),(1.25,.09,.12),"accent","spin_y")
    r.box((0,1.35,0),(.12,.09,1.25),"light","spin_y")
    r = new("Sprout Bed",4).box((0,.15,0),(1.55,.3,1),"wood")
    for x in (-.5,0,.5):
        for z in (-.25,.25):r.cone((x,.42,z),(.26,.5,.26),"leaf","sway")
    r = new("Rain Collector",4).tube((0,.6,0),(.8,1.2,.8),"accent")
    r.cone((0,1.32,0),(1.3,.3,1.3),"light").tube((.5,.75,0),(.12,.65,.12))
    r = new("Mushroom Log",4).tube((0,.3,0),(.48,1.4,.48),"wood",rotation=(0,0,90))
    for x in (-.45,0,.45):
        r.tube((x,.62,0),(.12,.45,.12),"light").ball((x,.87,0),(.42,.22,.42),"accent")
    r = new("Soil Scanner",4).box((0,.5,0),(.55,1,.4),"light")
    r.box((0,1.03,.12),(.5,.2,.12),"accent","glow").tube((.35,.37,0),(.06,.7,.06))
    r = new("Grow Lamp",4).legs(1.15,.65,1.65)
    r.box((0,1.7,0),(1.4,.16,.75),"light").box((0,1.59,0),(1.2,.02,.6),"accent","glow")
    r = new("Pollinator Hive",4).box((0,.2,0),(.75,.4,.7),"wood")
    r.box((0,.25,.34),(.25,.06,.06),"dark")
    for y in (.55,.82,1.09):r.object(f"hive_tray_{y}").box((0,y,0),(.65,.24,.6),"bread")
    r.object("hive_lid").cone((0,1.37,0),(.9,.35,.9),"accent")

    r = new("Ticket Machine",5).box((0,.85,0),(.65,1.7,.5))
    r.box((0,1.25,.27),(.47,.48,.04),"light","glow").box((0,.6,.28),(.36,.1,.05),"dark")
    r = new("Turnstile",5).box((0,.55,0),(.34,1.1,.9))
    r.box((0,1,0),(1.3,.065,.065),"metal","spin_y")
    r = new("Curb Charger",5).tube((0,.55,0),(.3,1.1,.3),"light")
    r.box((0,1.2,0),(.5,.45,.3)).box((.3,.65,0),(.1,.8,.12),"dark","sway")
    r = new("Bicycle Dock",5).box((0,.1,0),(1.65,.2,.7))
    for i,x in enumerate((-.6,0,.6)):r.object(f"dock_{i}").box((x,.585,0),(.08,.75,.5),"metal")
    r = new("Rail Buffer",5).box((0,.1,0),(1.7,.2,1),"wood")
    r.box((0,.55,0),(1.5,.18,.22),"accent").legs(1.2,.6,.55)
    r = new("Rain Shelter",5).canopy(1.85,1.2,2.1)
    r.box((0,1.1,-.49),(1.7,1.8,.05),"light")
    r.object("bench").table(1.5,.5,.55)
    r = new("Luggage Carousel",5).box((0,.38,0),(1.9,.75,1),"dark")
    r.box((0,.78,0),(1.8,.06,.92),"metal")
    r.object("suitcase").box((0,1.045,0),(.52,.45,.38),"accent","slide")
    r = new("Crossing Semaphore",5).tube((0,1,0),(.15,2,.15))
    r.box((.44,1.45,0),(1.15,.15,.12),"accent","rock")
    r = new("Tram Stop",5).tube((0,.9,0),(.12,1.8,.12))
    r.box((0,1.85,0),(.82,.58,.14),"accent").box((0,1,.12),(.4,.48,.05),"light")
    r = new("Route Globe",5).tube((0,.55,0),(.16,1.1,.16))
    r.ball((0,1.38,0),(.86,.86,.86),"accent","spin_y")
    r.tube((0,.08,0),(.7,.16,.7),"light")

    r = new("Pocket Ferris Wheel",6).legs(1.2,.7,1.2)
    r.tube((0,1.35,0),(1.6,.12,1.6),"accent","spin_z",(90,0,0))
    for x in (-.65,.65):r.box((x,1.4,.15),(.3,.35,.28),"light","bob")
    r = new("Carousel",6).tube((0,.12,0),(1.65,.24,1.65),"wood")
    r.tube((0,1,0),(.12,1.8,.12)).cone((0,1.95,0),(1.8,.45,1.8),"accent","spin_y")
    for x in (-.55,.55):r.box((x,.9,0),(.32,.24,.65),"light","bob")
    r = new("Drum Stage",6).box((0,.13,0),(1.8,.26,1.3),"wood")
    r.tube((0,.62,0),(.8,.65,.8),"accent","pump",(90,0,0))
    r = new("Speaker Stack",6)
    for y in (.4,1.12):
        r.object("frame" if y==.4 else "upper_speaker").box((0,y,0),(.72,.7,.65),"dark").tube((0,y,.35),(.45,.06,.45),"accent","glow",(90,0,0))
    r = new("Pipe Organ",6).box((0,.35,0),(1.5,.7,.8),"wood")
    for i in range(5):r.tube((-.55+i*.275,1.15+i*.11,0),(.16,1.0+i*.22,.16),"metal")
    r = new("Lantern Mobile",6).tube((0,1.15,0),(.08,2.3,.08))
    r.box((0,2.25,0),(1.6,.05,.05),"metal","sweep")
    for x in (-.65,0,.65):r.ball((x,1.85,0),(.34,.45,.34),"accent","bob")
    r = new("Popcorn Machine",6).box((0,.5,0),(.75,1,.7))
    r.legs(.65,.6,1.75).box((0,1.75,0),(.95,.15,.9),"accent")
    r.tube((0,1.28,0),(.5,.28,.5),"metal","rock")
    r = new("Swing Spinner",6).tube((0,1,0),(.15,2,.15))
    r.box((0,2,0),(1.6,.1,.15),"accent","spin_y")
    for x in (-.6,.6):r.box((x,1.05,0),(.4,.1,.5),"wood","sway")
    r = new("Balloon Cart",6).table(1.1,.8,.65)
    for x in (-.35,.05,.35):
        r.tube((x,1.3,0),(.025,1.2,.025),"light").ball((x,1.95,0),(.48,.65,.48),"accent","bob")
    r = new("Puppet Booth",6).box((0,.5,0),(1.4,1,.7))
    r.canopy(1.6,.9,2).box((0,1.2,0),(.22,.42,.2),"light","bob")

    r = new("Wind Turbine",7).tube((0,1.1,0),(.15,2.2,.15),"light")
    r.box((0,2.2,.1),(1.8,.09,.12),"accent","spin_z")
    r.box((0,2.2,.1),(.09,1.8,.12),"light","spin_z")
    r = new("Transformer",7).box((0,.75,0),(1.1,1.5,.8))
    for x in (-.3,0,.3):r.tube((x,1.65,0),(.13,.4,.13),"light")
    r = new("Flywheel Generator",7).box((0,.2,0),(1.4,.4,.85))
    r.tube((0,.9,0),(1.15,.24,1.15),"accent","spin_z",(90,0,0))
    r = new("Cooling Tower",7).cone((0,.85,0),(1.2,1.7,1.2),"light")
    r.tube((0,1.7,0),(.55,.15,.55),"dark").ball((0,2,0),(.45,.5,.45),"light","steam")
    r = new("Battery Stack",7)
    for x in (-.27,.27):
        for z in (-.25,.25):r.tube((x,.7,z),(.42,1.4,.42),"accent")
    r.box((0,1.45,0),(.9,.1,.85),"metal")
    r = new("Solar Tracker",7).tube((0,.7,0),(.16,1.4,.16))
    r.box((0,1.45,0),(1.6,.07,1.1),"dark","rock",(18,0,0))
    r = new("Street Sweeper",7).box((0,.48,0),(.7,.75,1.25))
    r.tube((0,.15,-.65),(.6,.14,.6),"accent","spin_y")
    for z in (-.35,.4):r.wheel((.39,.22,z),.2);r.wheel((-.39,.22,z),.2)
    r = new("Water Purifier",7).legs(1,.6,.4)
    for x in (-.35,.35):r.tube((x,1,0),(.45,1.45,.45),"light")
    r.box((0,1.8,0),(1.1,.2,.5),"accent","glow")
    r = new("Heat Exchanger",7).box((0,.15,0),(1.2,.3,.85))
    for x in (-.45,-.15,.15,.45):r.box((x,.9,0),(.065,1.4,.75),"metal")
    r = new("Cable Spool",7).tube((0,.65,0),(1.05,.7,1.05),"dark","spin_x",(0,0,90))
    for x in (-.42,.42):r.tube((x,.65,0),(1.25,.12,1.25),"wood",rotation=(0,0,90))

    r = new("Parcel Quadcopter",8).box((0,.7,0),(.6,.25,.45))
    for x in (-.48,.48):
        for z in (-.4,.4):r.box((x,.9,z),(.55,.03,.08),"metal","spin_y")
    r.box((0,.4,0),(.4,.32,.35),"wood")
    r = new("Parcel Locker",8).box((0,.95,0),(1.2,1.9,.6))
    for x in (-.28,.28):
        for y in (.35,.9,1.45):r.box((x,y,.32),(.48,.45,.05),"light")
    r = new("Landing Beacon",8).cone((0,.5,0),(.9,1,.9))
    r.ball((0,1.1,0),(.35,.28,.35),"accent","glow")
    r = new("Fuel Cart",8).table(1.35,.7,.35)
    r.tube((0,.86,0),(.7,1.1,.7),"accent",rotation=(0,0,90))
    for x in (-.45,.45):r.wheel((x,.19,0),.19)
    r = new("Baggage Tug",8).box((0,.5,0),(.85,.65,1.5))
    r.box((0,1.04,.3),(.75,.5,.65),"light")
    for z in (-.5,.5):r.wheel((.45,.2,z),.2);r.wheel((-.45,.2,z),.2)
    r = new("Luggage Scanner",8).table(1.8,.85,.6)
    r.box((-.5,1.08,0),(.16,.9,.85)).box((.5,1.08,0),(.16,.9,.85))
    r.box((0,1.55,0),(1.15,.16,.85))
    r.object("luggage").box((0,.88,0),(.42,.4,.4),"accent","slide")
    r = new("Cargo Pod",8).box((0,.6,0),(1.1,1.2,1.3),"light")
    for x in (-.43,.43):r.box((x,.6,0),(.08,1.25,1.35),"accent")
    r = new("Windsock",8).tube((0,1.05,0),(.1,2.1,.1))
    r.cone((.4,1.95,0),(.45,.95,.45),"accent","sway")
    r = new("Control Tower",8).box((0,.95,0),(.6,1.9,.6),"light")
    r.box((0,2,0),(1.1,.42,1)).box((0,2.26,0),(1.25,.08,1.15),"accent")
    r = new("Radar Pedestal",8).box((0,.5,0),(.7,1,.7))
    r.box((0,1.5,0),(1.4,.65,.08),"accent","sweep").tube((0,1.2,0),(.1,.5,.1))

    r = new("Kinetic Arch",9).legs(1.5,.55,1.8)
    r.box((0,1.88,0),(1.7,.15,.55),"accent").ball((0,1.1,0),(.5,.5,.5),"light","sway")
    r = new("Spiral Totem",9).tube((0,1.1,0),(.12,2.2,.12))
    for i in range(7):r.box((0,.25+i*.27,0),(.75,.09,.17),"accent","spin_y",(0,i*30,0))
    r = new("Balance Stones",9)
    for i,(y,s) in enumerate(((.25,.85),(.68,.65),(1.11,.48))):
        r.object("frame" if i==0 else f"stone_{i}").ball((0,y,0),(s,.43,s*.8),"stone")
    r = new("Chime Frame",9).legs(1.4,.65,2)
    r.box((0,2,0),(1.6,.08,.12),"wood")
    for i in range(5):r.tube((-.5+i*.25,1.3+i*.08,0),(.08,.9-i*.1,.08),"metal","sway")
    r = new("Pendulum Clock",9).legs(.9,.55,1.9)
    r.ball((0,1.65,0),(.6,.6,.2),"light")
    r.box((0,.95,0),(.05,.8,.08),"metal","rock").ball((0,.5,0),(.3,.3,.16),"accent","sway")
    r = new("Sundial",9).tube((0,.36,0),(1,.72,1),"stone")
    r.cone((0,.95,0),(.45,.65,.45),"metal")
    r = new("Mirror Fan",9).tube((0,.75,0),(.12,1.5,.12))
    for i in range(5):r.box((0,1.5,0),(1.2,.09,.06),"light","spin_z",(0,0,i*36))
    r = new("Ribbon Gate",9)
    for x in (-.65,.65):r.box((x,.95,0),(.14,1.9,.16),"accent",rotation=(0,0,10 if x<0 else -10))
    r.box((0,1.95,0),(1.4,.2,.2),"light","sway")
    r = new("Fractal Tree",9).tube((0,.65,0),(.18,1.3,.18),"wood")
    for x in (-.43,0,.43):
        r.box((x,1.25,0),(.08,.8,.08),"wood",rotation=(0,0,-30 if x<0 else 30))
        r.cone((x,1.65,0),(.6,.65,.6),"leaf","sway")
    r = new("Mist Fountain",9).tube((0,.18,0),(1.6,.36,1.6),"stone")
    r.tube((0,.7,0),(.16,1,.16),"accent","pump").ball((0,1.3,0),(.35,.25,.35),"light","steam")

    assert len(kit) == 100, len(kit)
    districts = [dict(id=i,name=n,center=list(c),color=t) for i,n,c,t in DISTRICTS]
    actors = []
    for idx,r in enumerate(kit):
        signature = [{k:v for k,v in p.items() if k not in ('tone','object_id')} for p in r.parts]
        objects = list(dict.fromkeys(p['object_id'] for p in r.parts))
        assert 'frame' in objects, r.name
        local = idx % 10
        center = districts[r.district]['center']
        actors.append(dict(id=r.name.lower().replace(' ', '_'), name=r.name,
                           district=districts[r.district]['id'],
                           position=[center[0]+(local%5-2)*3.2, center[1]+(local//5-.5)*5.2],
                           points=3, parts=r.parts, objects=[dict(id=o, support='frame' if o!='frame' else '') for o in objects],
                           geometry_recipe_sha256=hashlib.sha256(json.dumps(signature,sort_keys=True).encode()).hexdigest()))
    assert len({a['geometry_recipe_sha256'] for a in actors}) == 100
    return dict(schema=2,units=dict(size='full_xyz_extent_meters',rotation='degrees'),authoring='Original procedural component recipes',seed=20260926,
                type_count=len(actors),districts=districts,actors=actors)


if __name__ == '__main__':
    output=ROOT/'assets'/'world_actors'/'recipes.json'
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(author(),indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(types=100,districts=10,output=str(output))))

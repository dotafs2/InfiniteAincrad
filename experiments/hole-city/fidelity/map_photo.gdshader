shader_type canvas_item;
uniform vec2 extent=vec2(416.0,280.0);
varying vec2 local_position;
varying vec4 tint;
void vertex(){local_position=VERTEX;tint=COLOR;}
void fragment(){
	vec4 pixel=texture(TEXTURE,UV)*tint;
	float radius=20.0;
	vec2 q=abs(local_position-extent*.5)-(extent*.5-vec2(radius));
	float distance=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-radius;
	pixel.a*=1.0-smoothstep(-.6,.6,distance);
	COLOR=pixel;
}

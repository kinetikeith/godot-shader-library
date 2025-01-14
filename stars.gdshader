shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float voxel_size : hint_range(0.001, 1.0, 0.001) = 0.1;

vec3 screen(vec3 a, vec3 b) {
	return (1. - ((1. - a) * (1. - b)));
}

vec2 pixel_from_view(vec3 pos, mat4 pm, vec2 view_size) {
	vec4 pcs = pm * vec4(pos, 1.0);
	vec2 ndc = pcs.xy / pcs.w;
	return (ndc.xy * 0.5 + 0.5) * view_size;
}

vec3 hash(vec3 p) {
    p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5,183.3,246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
    p = fract(sin(p) * 43758.5453123);
    return p;
}

uniform float step_ratio = 1.0;
uniform int steps = 20;
uniform float depth = 1.0;
uniform float depth_falloff : hint_range(0.01, 1.0, 0.01) = 0.3;
uniform float y_falloff : hint_range(0.01, 2.0, 0.01) = 0.3;

float traverse_voxels(vec3 origin, vec3 direction, mat4 mvm, mat4 pm, vec2 view_size, vec2 screen_uv) {
	vec3 ray_step = normalize(direction) * voxel_size * step_ratio;
	vec3 current = origin;
	for(int i = 0; i < steps; i++) {
		vec3 current_voxel = round(current / voxel_size) * voxel_size;
		vec3 voxel_rand = current_voxel + (hash(current_voxel + 5.) - 0.5) * voxel_size;
		vec3 rand = hash(current_voxel + 10.);
		
		vec2 voxel_coord = pixel_from_view((mvm * vec4(voxel_rand, 1.0)).xyz, pm, view_size);
		vec2 pixel_coord = screen_uv * view_size;
		
		if(ivec2(voxel_coord) == ivec2(pixel_coord)) {
			float time_intensity = pow(sin((TIME + (rand.x * 1.25)) * PI) * 0.5 + 0.5, 2.0);
			float ray_length = length(origin - current);
			float intensity = clamp(pow(depth_falloff, ray_length / depth) * pow(current.y + 0.5, 1.0/y_falloff), 0., 1.) * 1.5;
			return intensity * time_intensity;
		}
		current += ray_step;
	}
	return pow(hash(origin).x, 8.) * 0.;
}

uniform vec3 color_a : source_color;
uniform vec3 color_b : source_color;

void fragment() {
	vec4 prev_color = texelFetch(screen_texture, ivec2(SCREEN_UV * VIEWPORT_SIZE), 0);
	
	mat4 INV_MODEL_MATRIX = inverse(MODEL_MATRIX);
	mat4 INV_MODELVIEW_MATRIX = INV_MODEL_MATRIX * INV_VIEW_MATRIX;
	vec3 model_fragcoord = (INV_MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 camera_coord = (INV_MODEL_MATRIX * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 ray_direction = normalize(model_fragcoord - camera_coord);
	vec3 target = vec3(0., 0., 0.);
	//vec3 tdist = (model_fragcoord - target) - (dot(model_fragcoord - target, ray_direction) * ray_direction);
	//vec3 model_fragcoord = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX * vec4(0.0, VERTEX.yz, 1.0)).xyz;
	//ALBEDO = screen(prev_color.rgb, vec3(pow(1. - length(tdist), 5.0), 0., 0.));
	//ALBEDO = model_fragcoord;
	float val = traverse_voxels(model_fragcoord, ray_direction, VIEW_MATRIX * MODEL_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE, SCREEN_UV);
	vec3 depth_color = mix(color_a, color_b, val);
	ALBEDO = screen(prev_color.rgb, depth_color);
}
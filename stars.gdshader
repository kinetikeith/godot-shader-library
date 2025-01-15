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

uniform int steps = 20;
uniform float depth = 1.0;
uniform float depth_falloff : hint_range(0.01, 1.0, 0.01) = 0.3;
uniform float y_falloff : hint_range(0.01, 2.0, 0.01) = 0.3;
uniform float entrance_bias: hint_range(0.0, 1.0, 0.001) = 0.001;

float traverse_voxels(vec3 origin, vec3 direction, mat4 mvm, mat4 pm, vec2 view_size, vec2 screen_uv) {
	vec3 norm_dir = normalize(direction);
	vec3 step_dir = sign(direction) * voxel_size;
	vec3 current = origin + (norm_dir * entrance_bias * voxel_size);
	ivec3 current_voxel = ivec3(floor(current / voxel_size));
	vec3 delta_t = 1.0 / norm_dir;
	for(int i = 0; i < steps; i++) {
		vec3 current_voxel_loc = vec3(current_voxel) * voxel_size;
		
		// BEGIN hit test
		vec3 voxel_rand = current_voxel_loc + ((hash(current_voxel_loc + 5.) * 2. - 0.5) * voxel_size);
		vec3 rand = hash(current_voxel_loc + 10.);
		vec2 voxel_coord = pixel_from_view((mvm * vec4(voxel_rand, 1.0)).xyz, pm, view_size);
		vec2 pixel_coord = screen_uv * view_size;
		if(ivec2(voxel_coord) == ivec2(pixel_coord)) {
			float time_intensity = pow(sin((TIME + (rand.x * 1.25)) * PI) * 0.5 + 0.5, 2.0);
			float ray_length = length(origin - current);
			float intensity = clamp(pow(depth_falloff, ray_length / depth) * pow(current.y + 0.5, 1.0/y_falloff), 0., 1.) * 1.5;
			return intensity * time_intensity;
		}
		// END hit test
		
		vec3 next = (vec3(current_voxel) + (sign(direction) * 0.5 + 0.5)) * voxel_size;
		vec3 a = (next - current) * delta_t;
		
		float t_step;
		if(a.x < a.y) {
			if(a.x < a.z) {
				t_step = a.x;
				current_voxel.x += int(sign(step_dir.x));
			} else {
				t_step = a.z;
				current_voxel.z += int(sign(step_dir.z));
			}
		} else {
			if(a.y < a.z) {
				t_step = a.y;
				current_voxel.y += int(sign(step_dir.y));
			} else {
				t_step = a.z;
				current_voxel.z += int(sign(step_dir.z));
			}
		}
		
		current += norm_dir * t_step;
	}
	return pow(hash(origin).x, 8.) * 0.;
}

uniform vec3 color_a : source_color;
uniform vec3 color_b : source_color;

void fragment() {
	vec4 prev_color = texelFetch(screen_texture, ivec2(SCREEN_UV * VIEWPORT_SIZE), 0);
	mat4 INV_MODELVIEW_MATRIX = inverse(VIEW_MATRIX * MODEL_MATRIX);
	
	/* The secret sauce for getting ray direction to work properly in orthogonal
	 * is using the following instead of -VIEW to obtain ray direction. */
	vec3 ray_direction = (INV_PROJECTION_MATRIX * vec4((SCREEN_UV * 2.) - 1., -1., 1.)).xyz;
	vec3 ray_origin = VERTEX;

	// transform ray to model space
	ray_origin = (INV_MODELVIEW_MATRIX * vec4(ray_origin,1)).xyz;
	ray_direction = normalize((INV_MODELVIEW_MATRIX * vec4(ray_direction,0)).xyz);

	float val = traverse_voxels(ray_origin, ray_direction, VIEW_MATRIX * MODEL_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE, SCREEN_UV);
	vec3 depth_color = mix(color_a, color_b, val);
	ALBEDO = screen(prev_color.rgb, depth_color);
}
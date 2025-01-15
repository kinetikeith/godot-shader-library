shader_type spatial;
render_mode unshaded;

uniform float voxel_size : hint_range(0.001, 1.0, 0.001) = 0.1;

vec3 hash(vec3 p) {
    p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5,183.3,246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
    p = fract(sin(p) * 43758.5453123);
    return p;
}

uniform int steps = 20;
uniform float entrance_bias: hint_range(0.0, 1.0, 0.001) = 0.001;

vec3 traverse_voxels(vec3 origin, vec3 direction) {
	vec3 norm_dir = normalize(direction);
	vec3 step_dir = sign(direction) * voxel_size;
	vec3 current = origin + (norm_dir * entrance_bias * voxel_size);
	ivec3 current_voxel = ivec3(floor(current / voxel_size));
	vec3 delta_t = 1.0 / norm_dir;
	for(int i = 0; i < steps; i++) {
		vec3 current_voxel_loc = vec3(current_voxel) * voxel_size;
		
		// BEGIN hit test
		bool is_filled = hash(current_voxel_loc).x < 0.5;
		if(is_filled) return hash(current_voxel_loc + 0.5);
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
}

/*
vec3 traverse_voxels_naive(vec3 origin, vec3 direction) {
	vec3 norm_dir = normalize(direction);
	vec3 current = origin + (norm_dir * entrance_bias * voxel_size);
	for(int i = 0; i < steps; i++) {
		vec3 current_voxel_loc = vec3(floor(current / voxel_size)) * voxel_size;
				
		bool is_filled = hash(current_voxel_loc).x < 0.5;
		if(is_filled) return hash(current_voxel_loc + 0.5);
		
		current += norm_dir * voxel_size * 0.25;
	}
}
*/

void fragment() {
	mat4 INV_MODELVIEW_MATRIX = inverse(VIEW_MATRIX * MODEL_MATRIX);
	
	/* The secret sauce for getting ray direction to work properly in orthogonal
	 * is using the following instead of -VIEW to obtain ray direction. */
	vec3 ray_direction = (INV_PROJECTION_MATRIX * vec4((SCREEN_UV * 2.) - 1., -1., 1.)).xyz;
	vec3 ray_origin = VERTEX;

	// transform ray to model space
	ray_origin = (INV_MODELVIEW_MATRIX * vec4(ray_origin,1)).xyz;
	ray_direction = normalize((INV_MODELVIEW_MATRIX * vec4(ray_direction,0)).xyz);
	
	//vec3 model_fragcoord = (INV_MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	//vec3 ray_direction = normalize(mat3(INV_MODELVIEW_MATRIX) * -VIEW);
	ALBEDO = traverse_voxels(ray_origin, ray_direction);
}
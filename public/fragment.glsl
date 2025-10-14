#define COLOR_MODE 0

uniform uint viewDiameter;
uniform vec2 scrSize;
uniform sampler2D heightmap;

flat varying vec2 bufIdx;
varying float chunkMinY;
varying float chunkMaxY;
varying vec3 localPos;
varying mat4 invProjMat;
varying mat4 invViewMat;

struct Ray {
	vec3 pos;
	vec3 dir;
};

// pos's value is undefined when hit is false
struct Hit {
	bool hit;
	vec3 pos;
	uint steps;
};

Ray getPrimaryRay() {
	vec2 uv = (gl_FragCoord.xy / scrSize) * 2.0 - 1.0;
	vec4 targ = invProjMat * vec4(uv, 1.0, 1.0);
	vec4 dir = invViewMat * vec4(normalize(targ.xyz / targ.w), 0.0);
	return Ray(localPos, normalize(dir.xyz));
}

bool outOfChunk(ivec3 pos, int ofs) {
	int lo = -1 + ofs;
	int hi = 32 - ofs;
	return pos.x < lo || pos.x > hi
	    || pos.z < lo || pos.z > hi
	    || pos.y < int(chunkMinY * 32.0)
	    || pos.y > int(chunkMaxY * 32.0);
}

bool isHitAt(ivec3 pos) {
	vec3 p = vec3(pos);
	float y = p.y / 32.0;
	vec2 uv = (floor(p.xz) + 0.5) / 32.0;
	uv += bufIdx;
	uv /= float(viewDiameter);
	return texture(heightmap, uv).r > y;
}

Hit raymarch(Ray primary) {
	vec3 P = primary.pos * 32.0;
	vec3 D = primary.dir;

	vec3 sgn = sign(D);
	vec3 Pf = floor(P + 0.00002);

	ivec3 step = ivec3(sgn);
	ivec3 pos = ivec3(Pf);

	vec3 dt = abs(length(D) / D);
	vec3 ts = ((sgn * (Pf - P)) + (sgn * 0.5) + 0.5) * dt;

	bvec3 mask;
	uint i;

	for (i = 0u; i < max(64u, uint(chunkMaxY * 32.0) + 64u); i++) {
		if (outOfChunk(pos + step, 0)) break;
		if (isHitAt(pos) && !outOfChunk(pos, 1)) return Hit(true, vec3(pos) / 32.0, i);
		if (ts.x < ts.y && ts.x < ts.z) {
			ts.x += dt.x;
			pos.x += step.x;
		} else if (ts.y < ts.z) {
			ts.y += dt.y;
			pos.y += step.y;
		} else {
			ts.z += dt.z;
			pos.z += step.z;
		}
	}

	return Hit(false, vec3(pos), i);
}

vec3 heightColor(float h) {
	if (h < 0.3) {
		return mix(vec3(0.2, 0.1, 0.05), vec3(0.33, 0.27, 0.13), h / 0.3);
	} else if (h < 0.5) {
		return mix(vec3(0.33, 0.27, 0.13), vec3(0.1, 0.2, 0.1), (h - 0.3) / 0.2);
	} else if (h < 0.65) {
		return mix(vec3(0.1, 0.2, 0.1), vec3(0.0, 0.4, 0.0), (h - 0.5) / 0.15);
	} else if (h < 0.8) {
		return mix(vec3(0.0, 0.4, 0.0), vec3(0.0, 0.278, 0.0), (h - 0.65) / 0.15);
	} else {
		return mix(vec3(0.0, 0.278, 0.0), vec3(0.2, 0.6, 0.2), (h - 0.8) / 0.2);
	}
}

void main() {
	Ray ray = getPrimaryRay();
	Hit hit = raymarch(ray);

	if (hit.hit) {
#if COLOR_MODE == 0
		float normY = clamp((hit.pos.y - chunkMinY) / (chunkMaxY - chunkMinY), 0.0, 1.0);
		vec3 baseColor = heightColor(normY);
		vec3 lightDir = normalize(vec3(0.5, 2.0, 0.5));
		float lightIntensity = clamp(dot(normalize(vec3(0.5, 1.0, 0.5)), lightDir), 0.0, 1.0);
		vec3 shadowTint = vec3(0.2, 0.5, 0.1);
		vec3 finalColor = mix(shadowTint, baseColor, lightIntensity);
		gl_FragColor = vec4(finalColor, 1.0);
#elif COLOR_MODE == 1
		gl_FragColor = vec4(vec3(float(hit.steps) / float(256)) * 2.0, 1.0);
#elif COLOR_NODE == 2
		gl_FragColor = vec4(vec3(hit.pos.y / (chunkMaxY - chunkMinY)), 1.0);
#endif
	} else {
		discard;
	}
}

attribute vec4 transforms;

uniform uint viewDiameter;

flat varying vec2 bufIdx; // x,z after modulo
varying float chunkMinY;
varying float chunkMaxY;
varying vec3 localPos;
varying mat4 invProjMat;
varying mat4 invViewMat;

void main() {
	vec3 posPre = position + vec3(0.5);

	vec3 pos = posPre;
	pos.xz += transforms.xz;
	pos.y = (pos.y) * transforms.w;

	chunkMinY = transforms.y;
	chunkMaxY = transforms.y + transforms.w;

	localPos = posPre;
	localPos.xz = posPre.xz;
	localPos.y = (posPre.y) * transforms.w;

	gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);

	bufIdx.x = float(uint(transforms.x) % viewDiameter);
	bufIdx.y = float(uint(transforms.z) % viewDiameter);

	invProjMat = inverse(projectionMatrix);
	invViewMat = inverse(modelViewMatrix);
}

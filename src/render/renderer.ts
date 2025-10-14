import * as THREE from 'three';
import { Input } from '../input';
import { MovableCamera } from './camera';
import { ChunkManager } from '../core/chunkManager';

const VIEW_DIAMETER = 10; // Side length of the visible x-z rectangle of chunks
const CHUNK_SIZE = 32;    // Side length of a chunk in heightmap pixels
const HEIGHTMAP_SIZE = VIEW_DIAMETER*CHUNK_SIZE; // in heightmap pixels

export class Renderer {
	webgl = new THREE.WebGLRenderer();
	clock = new THREE.Clock();
	scene = new THREE.Scene();
	input = new Input(this.webgl.domElement);
	camera = new MovableCamera(this.input);
    
	bbTransforms = new Float32Array(VIEW_DIAMETER**2 * 4);

	chunks = new ChunkManager(VIEW_DIAMETER, CHUNK_SIZE);
	heightmapData = new Float32Array(HEIGHTMAP_SIZE**2);
	heightmap = new THREE.DataTexture(
		this.heightmapData,
		HEIGHTMAP_SIZE,
		HEIGHTMAP_SIZE,
		THREE.RedFormat,
		THREE.FloatType,
	);
	material = new THREE.ShaderMaterial({
		uniforms: {
			scrSize: new THREE.Uniform(new THREE.Vector2()),
			heightmap: { value: this.heightmap },
			viewDiameter: { value: VIEW_DIAMETER },
		},
	});
	bbGeom = new THREE.BoxGeometry(1, 1, 1);
	instance = new THREE.InstancedMesh(this.bbGeom, this.material, VIEW_DIAMETER**2);
	
	constructor(vsh: string, fsh: string) {
		this.resize();
		this.webgl.setAnimationLoop(() => this.tick());
		document.body.appendChild(this.webgl.domElement);
		document.onresize = this.resize;
		document.body.style.background = '#87CEFA';
		this.scene.background = new THREE.Color(0x87CEFA);
		this.webgl.setClearColor(0x87CEFA, 1);

		this.input = new Input(this.webgl.domElement);
		this.camera = new MovableCamera(this.input);
		this.input.registerMouseCb(evt => this.camera.tickMouse(evt));

		this.heightmap.needsUpdate = true;
		this.heightmap.minFilter = THREE.NearestFilter;
		this.heightmap.magFilter = THREE.NearestFilter;
		this.heightmap.wrapS = THREE.ClampToEdgeWrapping;
		this.heightmap.wrapT = THREE.ClampToEdgeWrapping;

		this.material.vertexShader = vsh;
		this.material.fragmentShader = fsh;

		this.instance.instanceMatrix.setUsage(THREE.StaticDrawUsage);
		// when the base instance is outside the view frustum, the other instances also disappear.
		// i don't think we can fix this, so just disable frustum culling entirely
		this.instance.frustumCulled = false;
		this.scene.add(this.instance);

		for (let i = 0; i < VIEW_DIAMETER * VIEW_DIAMETER; i++) {
			let x = i % VIEW_DIAMETER;
			let z = Math.floor(i/VIEW_DIAMETER);
			this.bbTransforms[i * 4 + 0] = x;
			this.bbTransforms[i * 4 + 1] = this.chunks.getMinY(x,z); // y min
			this.bbTransforms[i * 4 + 2] = z;
			this.bbTransforms[i * 4 + 3] = this.chunks.getBBHeight(x,z); // height
			this.updateRegion(x, z);
		}

		this.bbGeom.setAttribute(
			'transforms',
			new THREE.InstancedBufferAttribute(this.bbTransforms, 4),
		);
	}

	private updateRegion(x: number, z: number) {
		const patch = Renderer.createChunkPatchTex(this.chunks.getChunkData(x, z));
		const ofs = new THREE.Vector2(x * CHUNK_SIZE, z * CHUNK_SIZE);
		this.webgl.copyTextureToTexture(patch, this.heightmap, null, ofs);
	}

	private static createChunkPatchTex(chunk: Float32Array): THREE.DataTexture {
		const patch = new THREE.DataTexture(
			chunk,
			CHUNK_SIZE,
			CHUNK_SIZE,
			THREE.RedFormat,
			THREE.FloatType,
		);
		patch.needsUpdate = true;
		return patch;
	}

	private resize() {
		this.webgl.setSize(window.innerWidth, window.innerHeight);
		this.instance.material.uniforms.scrSize.value = new THREE.Vector2(
			window.innerWidth,
			window.innerHeight
		);
	}

	private tick() {
		const dt = this.clock.getDelta();
		this.camera.tick(dt);
		this.webgl.render(this.scene, this.camera.inner);
	}
}

import * as THREE from "three";
import { Renderer } from "./render/renderer";

const loader = new THREE.FileLoader();
const vsh = await loader.loadAsync('vertex.glsl');
const fsh = await loader.loadAsync('fragment.glsl');

new Renderer(vsh.toString(), fsh.toString());

#ifdef GL_ES
precision mediump float;
#endif

//#include "common/shapes.glsl"

uniform vec2 u_resolution;
uniform vec3 u_camera;
uniform float u_time;

#define CAMERA_FOV 01.
#define CAMERA_NEAR 0.0000001
#define CAMERA_FAR 1000.0
#define STEPS 500

vec2 getUv() {
	vec2 xy = gl_FragCoord.xy / u_resolution.xy;
	if (u_resolution.x > u_resolution.y) {
        xy.x *= u_resolution.x / u_resolution.y;
        xy.x += (u_resolution.y - u_resolution.x) / u_resolution.y / 2.0;
    } else {
        xy.y *= u_resolution.y / u_resolution.x;
	    xy.y += (u_resolution.x - u_resolution.y) / u_resolution.x / 2.0;
    }
	xy -= 0.5;
	return xy;
}

mat2 rot2D(float a){
    float s = sin(a);
    float c = cos (a);
    return mat2(c, -s, s, c);
}


//FORMAS///////////////////////////////////////
float sdSphere(vec3 p, float s){
    return length(p) - s;
}

float sdBox(vec3 p, vec3 b, float r){
    vec3 d = abs(p) - b + r;
    return length(max(d,0.0)) + min(max(d.x,max(d.y,d.z)),0.0) - r;
}

float sdTorus(vec3 p, vec2 t){
    vec2 q = vec2(length(p.xz)-t.x,p.y);
    return length(q)-t.y;
}
///////////////////////////////////////////////

//FUNCIONES////////////////////////////////////

float opUnion(float d1, float d2)
{
    return min(d1, d2);
}

float opSubstraction(float d1, float d2)
{
    return max(d1, -d2);
}

float opIntersection(float d1, float d2)
{
    return max(d1, d2);
}

float opXor(float d1, float d2)
{
    return max(min(d1, d2), -max(d1, d2));
}

float opSmoothUnion(float d1, float d2, float k)
{
    k *= 4.;
    float h = max(k - abs(d1 - d2), 0.0);
    return min(d1, d2) - h * h * 0.25 / k;
}

float opSmoothSubstraction(float d1, float d2, float k)
{
    k *= 4.;
    float h = max(k - abs(d1 + d2), 0.0);
    return max(d1, -d2) + h * h * 0.25 / k;
}

float opSmoothIntersection(float d1, float d2, float k)
{
    k *= 4.;
    float h = max(k - abs(d1 - d2), 0.0);
    return max(d1, d2) + h * h * 0.25 / k;
}
///////////////////////////////////////////////

float map(vec3 p){

    vec3 q = p;
    q.xz *= rot2D(u_time);

    vec3 boxPos = vec3(0, -.5, 0);
    vec3 boxSize = vec3(2, .5, 2);

    vec3 spherePos = vec3(0, + (pow(abs(sin(3.1415 * u_time) * 9.), 0.7) + 2.)/2., 0);
    //vec3 spherePos = vec3(0, + sin( u_time) + 2., 0);
    vec3 sphereSize = vec3(1.0);

    vec3 torusPos = vec3(0, 0, 0);
    vec2 torusSize = vec2(1.5, 0.3);

    float box = sdBox(p - boxPos, boxSize, .2);
    float sphere = sdSphere(p - spherePos, sphereSize.x);
    float torus = sdTorus(p - torusPos, torusSize);
    float ground = p.y + 1.;
    float shape1 = opSmoothSubstraction(box, torus, 0.05);
    return min(shape1, sphere);
}

struct Camera {
    vec3 position;
    vec3 target;
    vec3 forward;
    vec3 right;
    vec3 up;
    float fov;
	float near;
	float far;
};

Camera getCamera(vec3 position, vec3 target) {
    vec3 forward = normalize(target - position);
    vec3 right = vec3(0.0);
    vec3 up = vec3(0.0);
	Camera camera = Camera(position, target, forward, right, up, CAMERA_FOV, CAMERA_NEAR, CAMERA_FAR);
	camera.right = normalize(vec3(camera.forward.z, 0.0, -camera.forward.x));
	camera.up = normalize(cross(camera.forward, camera.right));
	return camera;
}

struct Marcher {
    vec3 origin;
    vec3 direction;
	float scale;
	float threshold;
	float distance;
	float depth;
};

Marcher getMarcher(Camera camera) {
	const float scale = 0.5;
	const float threshold = 0.0001; 
	vec2 xy = getUv();
	Marcher marcher = Marcher(
		camera.position,
		normalize(
            camera.forward + 
            (camera.fov * camera.right * xy.x) + 
            (camera.fov * camera.up * xy.y)
        ),
		scale,
		threshold,
		0.0,
		0.0
	);	
	return marcher;
}

float getDistance(Marcher marcher, Camera camera){
    float t = 0.;
    vec3 col = vec3(0);
    marcher.distance = 0.0;
    marcher.depth = camera.near;
    for(int i = 0; i < STEPS; i++){
        marcher.distance = map(marcher.origin + marcher.direction * marcher.depth);
        t += marcher.distance;
        col = vec3(t * .1);
        if (marcher.distance < marcher.threshold) break;
    }
    return (t);
}

vec3 getNormal(in vec3 p) {
    const float e = 0.0001;
    return normalize(vec3(
        map(p + vec3(e, 0.0, 0.0)) - map(p - vec3(e, 0.0, 0.0)),
        map(p + vec3(0.0, e, 0.0)) - map(p - vec3(0.0, e, 0.0)),
        map(p + vec3(0.0, 0.0, e)) - map(p - vec3(0.0, 0.0, e))
    ));
}

struct Surface {
    vec3 position;
    vec3 normal;
    vec3 rgb;
};

Surface getSurface(Marcher marcher){
    vec3 position = marcher.origin + marcher.direction * marcher.distance;
    vec3 normal = getNormal(position);
    Surface surface = Surface(position, normal, vec3(1.0, 1.0, 1.0));
    return surface;
}

void main(){
    //vec2 uv = getUv();
    //vec3 ro = vec3(0, 0, -5);
    //vec3 rd = normalize(vec3(uv, 1));
    float radius = 10.0;
    vec3 cameraPos = u_camera;
    vec3 cameraTarget = vec3(0, 0, 0);
    Camera camera = getCamera(u_camera * radius, cameraTarget);
    Marcher marcher = getMarcher(camera);
    Surface surface = getSurface(marcher); 
    vec3 ro = getMarcher(getCamera(cameraPos, cameraTarget)).origin;
    vec3 rd = getMarcher(getCamera(cameraPos, cameraTarget)).direction;
    vec3 col = vec3(0.1686, 0.1686, 0.1686);

    float t = 0.;

    for (int i = 0; i < STEPS; i++) {
        vec3 p = ro + rd * t;
        //float d = sphere(p + vec3(0, 0, 0), 1.0);
        float d = map(p);
        t += d;
        //col = getNormal(p) * 0.5 + 0.5;
        if (d < 0.0001){
            vec3 normal = getNormal(p);
            //col = normal * 1. + .2;
            //col /= vec3(t* .3);
            vec3 lightPos = vec3(1, 1, -1);
            vec3 lightCol = vec3(1.0, 0.8549, 0.6);
            vec3 ambient = vec3(1.0, 1.0, 1.0);
            float fuerzaDiffuse = max(0.0, dot(normal, normalize(lightPos)));
            vec3 diffuse = fuerzaDiffuse * lightCol;
            vec3 viewSource = normalize(cameraPos);
            vec3 reflectSource = normalize(reflect(-lightPos, normal));
            float specStrenght = max(0.0, dot(viewSource, reflectSource));
            specStrenght = pow(specStrenght, 6.0);
            vec3 specular = specStrenght * lightCol;
            vec3 light = ambient * 0.1 + diffuse * 1. + specular * 0.2;
            col = vec3(1.0, 1.0, 1.0) * light;
            break;
        }
    }
    //gl_FragColor = vec4(col, 1.0);
    gl_FragColor = vec4(col , 1.0);
}

#ifdef GL_ES
precision mediump float;
#endif

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

mat2 rot2D(float a){
    float s = sin(a);
    float c = cos (a);
    return mat2(c, -s, s, c);
}
///////////////////////////////////////////////

//MAPPING///////////////////////////////////

float map(vec3 p){
    vec3 q = p;
    
    float box = sdBox(p - vec3(0, -.5, 0), vec3(2, .5, 2), .2);
    float sphere = sdSphere(p - vec3(0, (pow(abs(sin(3.1415 * u_time) * 9.), 0.7) + 2.)/2., 0), 1.);
    float torus = sdTorus(p - vec3(0, 0, 0), vec2(1.5, 0.3));
    float shape1 = opSmoothSubstraction(box, torus, 0.05);
    return min(shape1, sphere);
}

///////////////////////////////////////////////

struct Camera{
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

struct Marcher{
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

vec3 getAmbient(){
    return vec3(1., 1., 1.);
}

vec3 getDiffuse(vec3 col, vec3 norm, vec3 lightPos){
    float diffStrg = max(0.0, dot(norm, normalize(lightPos)));
    return diffStrg * col;
}

vec3 getSpec(vec3 col, vec3 norm, vec3 lightPos, vec3 viewSource, float shine){
    vec3 reflectSource = normalize(reflect(-lightPos, norm));
    float specStrenght = max(0.0, dot(viewSource, reflectSource));
    specStrenght = pow(specStrenght, shine);
    return specStrenght * col;
}

void main(){
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
        float d = map(p);
        t += d;
        if (d < 0.0001){
            vec3 normal = getNormal(p);
            vec3 lightPos = vec3(1, 1, -1);
            vec3 lightCol = vec3(1.0, 0.8549, 0.6);
            vec3 viewSource = normalize(cameraPos);
            vec3 ambient = getAmbient();
            vec3 diffuse = getDiffuse(lightCol, normal, lightPos);
            vec3 specular = getSpec(lightCol, normal, lightPos, viewSource, 6.0);
            vec3 light = ambient * 0.1 + diffuse * 1. + specular * 0.2;
            col = vec3(1.0, 1.0, 1.0) * light;
            break;
        }
    }
    //gl_FragColor = vec4(col, 1.0);
    gl_FragColor = vec4(col , 1.0);
}
// language: glsl
// ここには「絵だけ」を素の Shadertoy 形式で書く。エディタ画面との合成は C-c C-c が自動で足す
//   C-c C-c 適用 / C-c C-o 絵だけ<->うっすら背景 / C-c C-k 解除
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float t = iTime * 0.9;
    vec3 col = 0.5 + 0.5 * cos(t + uv.xyx * 3.0 + vec3(0.0, 2.0, 4.0));
    fragColor = vec4(col, 1.0);
}

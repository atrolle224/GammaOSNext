#version 450

/*
   Snapdragon Game Super Resolution v1 (mobile, RGBA mode), ported to RetroArch slang.
   Copyright (c) 2025, Qualcomm Innovation Center, Inc. SPDX-License-Identifier: BSD-3-Clause
   (see ../LICENSE-SGSR.txt)
*/

#pragma parameter SGSR_THRESHOLD "SGSR Edge Threshold (x/255)" 8.0 1.0 32.0 1.0
#pragma parameter SGSR_SHARPNESS "SGSR Edge Sharpness" 2.0 1.0 4.0 0.1

layout(push_constant) uniform Push
{
   vec4 SourceSize;
   vec4 OutputSize;
   uint FrameCount;
   float SGSR_THRESHOLD;
   float SGSR_SHARPNESS;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float fastLanczos2(float x)
{
   float wA = x - 4.0;
   float wB = x * wA - wA;
   wA *= wA;
   return wB * wA;
}

vec2 weightY(float dx, float dy, float c, float stdv)
{
   float x = ((dx * dx) + (dy * dy)) * 0.55 + clamp(abs(c) * stdv, 0.0, 1.0);
   float w = fastLanczos2(x);
   return vec2(w, w * c);
}

void main()
{
   const int mode = 1;
   vec4 info = vec4(params.SourceSize.zw, params.SourceSize.xy);
   vec4 color = vec4(texture(Source, vTexCoord).xyz, 0.0);

   vec2 imgCoord = vTexCoord * info.zw + vec2(-0.5, 0.5);
   vec2 imgCoordPixel = floor(imgCoord);
   vec2 coord = imgCoordPixel * info.xy;
   vec2 pl = imgCoord - imgCoordPixel;
   vec4 left = textureGather(Source, coord, mode);

   float edgeVote = abs(left.z - left.y) + abs(color[mode] - left.y) + abs(color[mode] - left.z);
   if (edgeVote > params.SGSR_THRESHOLD / 255.0)
   {
      coord.x += info.x;

      vec4 right = textureGather(Source, coord + vec2(info.x, 0.0), mode);
      vec4 upDown;
      upDown.xy = textureGather(Source, coord + vec2(0.0, -info.y), mode).wz;
      upDown.zw = textureGather(Source, coord + vec2(0.0, info.y), mode).yx;

      float mean = (left.y + left.z + right.x + right.w) * 0.25;
      left -= vec4(mean);
      right -= vec4(mean);
      upDown -= vec4(mean);
      color.w = color[mode] - mean;

      float sum = abs(left.x) + abs(left.y) + abs(left.z) + abs(left.w)
                + abs(right.x) + abs(right.y) + abs(right.z) + abs(right.w)
                + abs(upDown.x) + abs(upDown.y) + abs(upDown.z) + abs(upDown.w);
      float stdv = 2.181818 / sum;

      vec2 aWY = weightY(pl.x, pl.y + 1.0, upDown.x, stdv);
      aWY += weightY(pl.x - 1.0, pl.y + 1.0, upDown.y, stdv);
      aWY += weightY(pl.x - 1.0, pl.y - 2.0, upDown.z, stdv);
      aWY += weightY(pl.x, pl.y - 2.0, upDown.w, stdv);
      aWY += weightY(pl.x + 1.0, pl.y - 1.0, left.x, stdv);
      aWY += weightY(pl.x, pl.y - 1.0, left.y, stdv);
      aWY += weightY(pl.x, pl.y, left.z, stdv);
      aWY += weightY(pl.x + 1.0, pl.y, left.w, stdv);
      aWY += weightY(pl.x - 1.0, pl.y - 1.0, right.x, stdv);
      aWY += weightY(pl.x - 2.0, pl.y - 1.0, right.y, stdv);
      aWY += weightY(pl.x - 2.0, pl.y, right.z, stdv);
      aWY += weightY(pl.x - 1.0, pl.y, right.w, stdv);

      float finalY = aWY.y / aWY.x;
      float maxY = max(max(left.y, left.z), max(right.x, right.w));
      float minY = min(min(left.y, left.z), min(right.x, right.w));
      finalY = clamp(params.SGSR_SHARPNESS * finalY, minY, maxY);

      float deltaY = clamp(finalY - color.w, -23.0 / 255.0, 23.0 / 255.0);
      color.xyz = clamp(color.xyz + deltaY, 0.0, 1.0);
   }

   FragColor = vec4(color.xyz, 1.0);
}

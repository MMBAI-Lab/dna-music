// basePath is read from env so we can build for both:
//   • mmbai-lab.github.io/dna-music/   (NEXT_PUBLIC_BASE_PATH=/dna-music)
//   • a custom domain at root          (NEXT_PUBLIC_BASE_PATH unset)
const basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";

/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "export",
  trailingSlash: true,
  basePath,
  assetPrefix: basePath || undefined,
  images: { unoptimized: true },
  env: {
    NEXT_PUBLIC_BASE_PATH: basePath,
  },
};

export default nextConfig;

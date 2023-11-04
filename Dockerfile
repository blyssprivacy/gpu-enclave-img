FROM docker.io/local/llama.cpp:full-cuda

WORKDIR /app

COPY phind-codellama-34b-v2.Q6_K.gguf .

CMD ["-s", "-m", "/app/phind-codellama-34b-v2.Q6_K.gguf", "-ngl", "99999", "--port", "8080"]




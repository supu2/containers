FROM ollama/ollama:0.9.2 AS builder

# Start Ollama server in background and wait for it to become ready
RUN nohup ollama serve > /tmp/ollama.log 2>&1 & \
    sleep 10 && \
    ollama pull openchat:7b

# Final image
FROM ollama/ollama:0.9.2

# Copy preloaded model cache
COPY --from=builder /root/.ollama /root/.ollama

# Expose Ollama port
EXPOSE 11434
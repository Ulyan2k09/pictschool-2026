FROM python:3.12-slim
WORKDIR /app
COPY simulation-emulator/ ./simulation-emulator/
EXPOSE 5055
CMD ["python", "simulation-emulator/tcp_emulator.py", "--host", "0.0.0.0", "--port", "5055", "--agent-mode", "auto"]

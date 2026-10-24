# Fake tuner for Live TV tests (see fake_tuner.py).
FROM python:3.13-alpine3.22
RUN apk add --no-cache ffmpeg font-dejavu
COPY fake_tuner.py /app/fake_tuner.py
EXPOSE 5104
CMD ["python3", "-u", "/app/fake_tuner.py"]

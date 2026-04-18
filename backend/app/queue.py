from collections import deque
import threading
import uuid

class InMemoryQueue:
    def __init__(self):
        self.q = deque()
        self.lock = threading.Lock()

    def enqueue(self, job_id: str):
        with self.lock:
            self.q.append(job_id)

    def dequeue(self):
        with self.lock:
            if not self.q:
                return None
            return self.q.popleft()


queue = InMemoryQueue()
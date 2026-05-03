import numpy as np

# based on https://scimusing.wordpress.com/2013/10/25/ring-buffers-in-pythonnumpy/
class RingBuffer():
    "A 1D ring buffer using numpy arrays"
    def __init__(self, initial_data: bytes) -> None:
        self.data = np.frombuffer(initial_data, dtype=np.uint8).copy()
        self.index = 0

    def extend(self, x: bytes) -> int:
        if not len(x):
            return 0
        "adds array x to ring buffer"
        x_len = len(x)
        x_index = (self.index + np.arange(x_len)) % self.data.size
        self.data[x_index] = np.frombuffer(x, dtype=np.uint8)
        self.index = x_index[-1] + 1
        return x_len

    def advance(self, n: int) -> None:
        assert(self.extend(b"\0" * n) == n)

    def get(self) -> bytes:
        "Returns the first-in-first-out data in the ring buffer"
        return bytes(self.data[self.index:]) + bytes(self.data[:self.index])
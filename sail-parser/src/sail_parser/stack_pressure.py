from .tick import Tick, RegisterSideEffect
from io import StringIO

def is_valid_stack_assignment(regSE: RegisterSideEffect) -> bool:
    return regSE.tag and regSE.perms != 0 and regSE.address != regSE.base

class StackPressureTracker():
    initialized: bool = False
    skip: int = 0
    stack_base: int = 0
    stack_top: int = 0
    stack_cumul_alloc: int = 0
    prev_address: int = 0
    lowest_address: int = 0
    
    def __init__(self) -> None:
        return
    
    def process_tick(self, tick: Tick) -> None:
        if self.skip > 0:
            self.skip -= 1
            return
        stack_assignment = tick.get_assignment_for_reg(2)
        if stack_assignment is None or not is_valid_stack_assignment(stack_assignment):
            return
        # initialize from first valid assignment (assumed to be in crt0)
        if not self.initialized:
            self.stack_base = stack_assignment.base
            self.stack_top = stack_assignment.top
            self.lowest_address = stack_assignment.address
            self.prev_address = stack_assignment.address
            self.initialized = True
            self.skip = 50
            print(f"Initialized stack pointer: {self.lowest_address:08X} ({self.stack_base:08X},{self.stack_top:08X})")
            print("Skipping next 50 instructions")
            return
        # skip assignments out of bounds
        if not (self.stack_base < stack_assignment.address <= self.stack_top):
            return
        if self.prev_address > stack_assignment.address:
            self.stack_cumul_alloc += self.prev_address - stack_assignment.address
        self.prev_address = stack_assignment.address
        if self.lowest_address > stack_assignment.address:
            self.lowest_address = stack_assignment.address
    
    ## stack pressure in bytes
    @property
    def stack_pressure(self) -> int:
        return self.stack_top - self.lowest_address
        
    ## print summary
    def summarize(self, output: StringIO) -> None:
        output.write(f"guest.stack.lowestAddress    0x{self.lowest_address:08X}    # Lowest address assigned to the stack pointer register\n")
        output.write(f"guest.stack.pressure         0x{self.stack_pressure:08X}    # Highest amount of memory allocated on the stack\n")
        output.write(f"guest.stack.stackBase        0x{self.stack_base:08X}    # Base of the stack capability\n")
        output.write(f"guest.stack.stackTop         0x{self.stack_top:08X}    # Top of the stack capability\n")
        output.write(f"guest.stack.cumulativeAllocation {self.stack_cumul_alloc}    # Cumulative amount of stack allocated during execution\n")
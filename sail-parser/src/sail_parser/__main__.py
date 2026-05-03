"""Command-line interface."""
import click
from io import BytesIO
from .protobuf_out import _output_proto, _output_proto_from_queue
from .tick import Tick, parse_ticks, parse_ticks_into_queue
import tracemalloc
from multiprocessing import Queue, Process

snapshot : tracemalloc.Snapshot = None

@click.group()
def main() -> None:
    return

@main.command()
@click.pass_context
def help(ctx: click.Context) -> None:
    print(ctx.parent.get_help())

@main.command('output-proto', short_help='reformat trace to be compatible with gem5')
@click.argument('input', type=click.File('rb'))
@click.argument('data-output', type=click.File('wb'))
@click.argument('inst-output', type=click.File('wb'))
@click.argument('stats-output', type=click.File('w'), required=False, default="-")
@click.option('-c', '--compress', is_flag=True, help='Compress output files')
@click.option('--ticks-per-inst', type=int, default=2500)
@click.option('--count-cshrink/--no-count-cshrink', default=False)
@click.pass_context
def output_proto(ctx: click.Context, input: BytesIO, data_output: click.File, inst_output: click.File, stats_output: click.File, compress: bool, **kwargs: int) -> None:
    tick_generator = parse_ticks(input, stats_output, **kwargs)
    _output_proto(tick_generator, data_output, inst_output, stats_output, compress, **kwargs)

# @main.command('output-proto-traced', short_help='reformat trace to be compatible with gem5')
# @click.argument('input', type=click.File('rb'))
# @click.argument('data-output', type=click.File('wb'))
# @click.argument('inst-output', type=click.File('wb'))
# @click.argument('mem-trace-output', type=click.Path())
# @click.option('-c', '--compress', is_flag=True, help='Compress output files')
# @click.option('--ticks-per-inst', type=int, default=2500)
# @click.pass_context
# def mem_traced_output_proto(ctx: click.Context, input: StringIO, data_output: click.File, inst_output: click.File, mem_trace_output: click.Path, compress: bool, **kwargs: int) -> None:
#     _output_proto(input, data_output, inst_output, compress, **kwargs)
#     global snapshot
#     if snapshot is not None:
#         snapshot.dump(str(mem_trace_output))

@main.command('output-proto-threaded', short_help='reformat trace to be compatible with gem5')
@click.argument('tick-input', type=click.File('rb'))
@click.argument('data-output', type=click.File('wb'))
@click.argument('inst-output', type=click.File('wb'))
@click.option('-c', '--compress', is_flag=True, help='Compress output files')
@click.option('--queue-size', type=int, default=256)
@click.option('--ticks-per-inst', type=int, default=2500)
@click.pass_context
def threaded_output_proto(ctx: click.Context,
                          tick_input: BytesIO,
                          data_output: BytesIO,
                          inst_output: BytesIO,
                          compress: bool,
                          queue_size: int,
                          **kwargs: int) -> None:
    tick_queue : Queue[Tick] = Queue(maxsize=queue_size)
    # tick_process = Process(target=parse_ticks_into_queue, args=(tick_input, tick_queue))
    # tick_process.start()
    # _output_proto_from_queue(tick_queue, data_output, inst_output, compress, **kwargs)
    output_process = Process(target=_output_proto_from_queue, 
                             args=(tick_queue, data_output, inst_output, compress),
                             kwargs=kwargs)
    output_process.start()
    parse_ticks_into_queue(tick_input, tick_queue)
    # tick_process.join()
    output_process.join()

if __name__ == "__main__":
    main(prog_name="sail-parser")  # pragma: no cover

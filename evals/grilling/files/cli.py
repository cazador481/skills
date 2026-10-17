"""Tiny CLI used as a fixture for the grilling evals."""
import click


@click.group()
def run():
    """git-nv entry point."""


@run.command()
@click.option("--test", is_flag=True, help="We want to test")
@click.pass_obj
def as2_submit(nv_git, test):
    """Submits contents of the associated shelf to AS2."""
    if not nv_git.shelf:
        raise click.ClickException("No shelf created.")
    print("submitting", nv_git.shelf, "test" if test else "")

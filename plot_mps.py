import matplotlib as mpl
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.patches import Rectangle
from matplotlib.collections import PatchCollection
from matplotlib import cm
import re
import os
import json
import numpy as np
import pandas as pd
import json
import sys
from vtk import vtkUnstructuredGridReader
from vtk.util import numpy_support as VN
from vtk.util.numpy_support import vtk_to_numpy, numpy_to_vtk
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.patches import Rectangle
from matplotlib.collections import PatchCollection
from matplotlib import cm
from multiprocessing import Pool

plt.style.use("seaborn-paper")
plt.rc('font', family='serif', serif='Times')
# plt.rc('text', usetex=True)
plt.rc('xtick', labelsize=8)
plt.rc('ytick', labelsize=8)
plt.rc('axes', labelsize=8)
mpl.rcParams.update(
    {
        "pgf.texsystem": "pdflatex",
        "font.family": "serif",
        "font.serif": ["Computer Modern"],
        "text.usetex": True,
        "pgf.rcfonts": False,
        'figure.constrained_layout.use':True
    }
)
ratio = 1.2 #1.618
width = 5.9006*0.5
height = width / ratio
scale = 1


file_list = ["timing_mps.csv"]
for fname in file_list:
    fig = plt.figure(figsize=(scale*width,scale*height),dpi=200)
    # df = pd.read_csv("timing.csv")
    df = pd.read_csv(fname)
    # plt.title(fname)
    total_mpiter = df["mp-total"].values * df["iters"].values
    time = df["time"].values
    mps = df["mps"].values
    plt.scatter(mps,total_mpiter/time)
    plt.xlabel("MP per dimension per element")
    plt.ylabel("MP throughout (mp/s)")
    # plt.xscale("log")
    plt.legend()

plt.savefig("mps.pdf")
plt.show()

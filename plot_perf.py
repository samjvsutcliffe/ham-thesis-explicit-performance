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

file_list = os.listdir(".")
reg = re.compile("timing.*\.csv")
file_list = list(filter(reg.match,file_list))
print(file_list)

for fname in file_list:
    fig = plt.figure(figsize=(scale*width,scale*height),dpi=200)
    # df = pd.read_csv("timing.csv")
    df = pd.read_csv(fname)
    plt.title(fname)
    for name,group in df.groupby("refine"):
        mps = group["mps"].values
        time = group["time"].values
        total_mps = (mps**2) * ((8*name)**2)
        plt.scatter(total_mps,total_mps*100 / time,label="h = 1/{}".format(name))
    plt.xlabel("Total MPs")
    # plt.ylabel("Time (s)")
    plt.ylabel("MP throughout (mp/s)")
    plt.xscale("log")
    plt.legend()
plt.show()

import pandas as pd
import matplotlib.pyplot as plt
import sys

fig, ax = plt.subplots(3,1, figsize=(20,10))

df = pd.read_csv(sys.argv[1])

df_gyro = df[["gx","gy","gz"]]
df_accel = df[["ax","ay","az"]]
df_fifolevel = df[["debugdata"]]

df_gyro.plot(ax=ax[0], title="Gyro")
df_accel.plot(ax=ax[1], title="Accel")
df_fifolevel.plot(ax=ax[2], title="Debugdata")

plt.show()

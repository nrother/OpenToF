import pandas as pd
import matplotlib.pyplot as plt
import sys
df = pd.read_csv(sys.argv[1])
df_gyro = df[["gx","gy","gz"]]
df_accel = df[["ax","ay","az"]]
df_gyro.plot()
df_accel.plot()
plt.show()
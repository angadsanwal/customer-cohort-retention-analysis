import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os

# ======================================
# 1. Desktop Path
# ======================================
desktop_path = os.path.dirname(os.path.abspath(__file__))

# List all files on Desktop
desktop_path = os.path.join(desktop_path, "data")
files = os.listdir(desktop_path)
print("Files on Desktop:", files)

# Auto-find CSVs
retention_file = next((f for f in files if 'retention' in f.lower() and f.endswith('.csv')), None)
ltv_file = next((f for f in files if 'ltv' in f.lower() and f.endswith('.csv')), None)

if not retention_file or not ltv_file:
    raise FileNotFoundError("Retention or LTV CSV not found directly on Desktop!")

retention_file = os.path.join(desktop_path, retention_file)
ltv_file = os.path.join(desktop_path, ltv_file)

print(f"Using retention file: {retention_file}")
print(f"Using LTV file: {ltv_file}")

# ======================================
# 2️. Load CSVs
# ======================================
retention = pd.read_csv(retention_file)
ltv = pd.read_csv(ltv_file)

# Fix columns (keep only necessary ones)
retention = retention[['cohort_month', 'cohort_index', 'retention_percentage']]
ltv = ltv[['cohort_month', 'cohort_index', 'cumulative_ltv']]

# Add churn rate
retention['churn_rate'] = 100 - retention['retention_percentage']

# ======================================
# 3️. Retention Heatmap
# ======================================
retention_pivot = retention.pivot_table(
    index='cohort_month',
    columns='cohort_index',
    values='retention_percentage'
)

plt.figure(figsize=(12, 8))
plt.imshow(retention_pivot, aspect='auto', cmap='Blues')
plt.colorbar(label='Retention %')

plt.xticks(ticks=np.arange(len(retention_pivot.columns)), labels=retention_pivot.columns)
plt.yticks(ticks=np.arange(len(retention_pivot.index)), labels=retention_pivot.index)

plt.title("Customer Retention Cohort Analysis")
plt.xlabel("Months Since First Purchase")
plt.ylabel("Cohort Month")
plt.tight_layout()
plt.savefig(os.path.join(desktop_path, "retention_heatmap.png"))
plt.show()

# ======================================
# 4️. LTV Growth Chart
# ======================================
plt.figure(figsize=(12,6))

for cohort in ltv['cohort_month'].unique():
    cohort_data = ltv[ltv['cohort_month'] == cohort]
    plt.plot(
        cohort_data['cohort_index'],
        cohort_data['cumulative_ltv'],
        marker='o',
        label=str(cohort)
    )

plt.title("Cumulative Lifetime Value (LTV) by Cohort")
plt.xlabel("Months Since First Purchase")
plt.ylabel("Cumulative LTV")
plt.legend(title="Cohort Month", bbox_to_anchor=(1.05,1), loc='upper left')
plt.tight_layout()
plt.savefig(os.path.join(desktop_path, "ltv_growth.png"))
plt.show()

# ======================================
# 5️. Retention & Churn Insights
# ======================================
month_0 = retention[retention['cohort_index']==0]['retention_percentage'].mean()
month_1 = retention[retention['cohort_index']==1]['retention_percentage'].mean()
print("\n===== RETENTION INSIGHTS =====")
print(f"Month 0 retention: {month_0:.2f}%")
print(f"Month 1 retention: {month_1:.2f}%")
print(f"Drop from Month 0 to Month 1: {month_0 - month_1:.2f}%")
print(f"Average Churn Rate (Month 1): {100-month_1:.2f}%")

# ======================================
# 6️. LTV Insights
# ======================================
max_month = ltv['cohort_index'].max()
final_ltv = ltv[ltv['cohort_index'] == max_month]['cumulative_ltv'].mean()
month_3_ltv = ltv[ltv['cohort_index'] == 3]['cumulative_ltv'].mean()

print("\n===== LTV INSIGHTS =====")
print(f"Average LTV at Month 3: {month_3_ltv:.2f}")
print(f"Average Final LTV: {final_ltv:.2f}")

if month_3_ltv / final_ltv > 0.8:
    print("✅ Most revenue is generated in the first 3 months.")
else:
    print("⚠️ Revenue continues to grow beyond month 3.")

# ======================================
# 7️. Business Recommendations
# ======================================
best_cohort = ltv.groupby('cohort_month')['cumulative_ltv'].max().idxmax()
worst_cohort = ltv.groupby('cohort_month')['cumulative_ltv'].min().idxmin()

print("\n===== BUSINESS RECOMMENDATIONS =====")
print(f"💡 Best cohort (highest LTV): {best_cohort}")
print(f"💡 Worst cohort (lowest LTV): {worst_cohort}")
print("💡 Suggest targeting retention campaigns for cohorts with highest Month-1 drop.")
print("💡 Send emails, push notifications, or discounts to improve churn.")

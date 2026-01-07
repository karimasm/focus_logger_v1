# Epic: Analytics & Insights (Phase 5)

## Epic ID: FLOW-E005
## Status: Planned
## Priority: High

## Description
Provide users with meaningful insights about their time usage, patterns, and trends to increase self-awareness and support behavior change.

## Business Value
- Helps users understand where their time goes
- Identifies patterns (productive times, common distractions)
- Motivates through progress visualization
- Supports goal-setting with data

## User Stories

### Story 1: Daily Summary Dashboard
**As a** user  
**I want** to see a summary of today's activities  
**So that** I understand how I spent my time  

**Acceptance Criteria:**
- [ ] Total time tracked today
- [ ] Breakdown by category (pie chart)
- [ ] Number of activities logged
- [ ] Longest activity duration
- [ ] Idle time detected

### Story 2: Weekly Trends
**As a** user  
**I want** to see my weekly activity trends  
**So that** I can identify patterns over time  

**Acceptance Criteria:**
- [ ] Bar chart showing daily logged hours
- [ ] Comparison to previous week
- [ ] Most common activities
- [ ] Average session length

### Story 3: Focus Streaks
**As a** user  
**I want** to see my focus streaks  
**So that** I'm motivated to maintain consistency  

**Acceptance Criteria:**
- [ ] Current streak (consecutive days with activity)
- [ ] Longest streak achieved
- [ ] Visual streak calendar
- [ ] Celebration for milestones (7, 14, 30 days)

### Story 4: Energy Correlation
**As a** user  
**I want** to see how my energy levels correlate with activities  
**So that** I can optimize my schedule  

**Acceptance Criteria:**
- [ ] Average energy by time of day
- [ ] Average energy by activity type
- [ ] Trend over past 7/30 days
- [ ] Recommendations based on data

### Story 5: Export Data
**As a** user  
**I want** to export my activity data  
**So that** I can analyze it externally or share with therapist  

**Acceptance Criteria:**
- [ ] Export as CSV
- [ ] Export as JSON
- [ ] Date range selection
- [ ] Include/exclude categories

## Technical Considerations

### Data Aggregation
- Pre-compute daily/weekly summaries for performance
- Store aggregates in separate table or compute on-demand
- Consider local-only vs synced analytics

### Charts Library
- Use `fl_chart` or `syncfusion_flutter_charts`
- Keep visualizations simple and accessible
- Support dark/light theme

### Privacy
- All analytics computed locally
- No data sent to external analytics services
- Export includes all user data (GDPR compliance)

## Dependencies
- Requires sufficient historical data (suggest after 1 week of use)
- Energy check-in adoption

## Estimated Effort
- **Story 1**: 3 days
- **Story 2**: 4 days
- **Story 3**: 2 days
- **Story 4**: 3 days
- **Story 5**: 2 days
- **Total**: ~14 days

## Out of Scope (for this epic)
- Social features / comparisons
- AI-generated insights
- Push notifications for insights
- Goal setting (separate epic)

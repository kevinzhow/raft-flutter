-- Isolated development fixtures only: align fixture denormalization with real writes.
UPDATE channel_humans AS h
SET joined_at = LEAST(h.joined_at, m.earliest - INTERVAL '1 second')
FROM (
  SELECT channel_id, min(created_at) AS earliest FROM messages GROUP BY channel_id
  UNION ALL
  SELECT s.local_channel_id, min(m.created_at)
  FROM joint_channel_servers s JOIN joint_channels j ON j.id=s.joint_channel_id
  JOIN messages m ON m.channel_id=j.canonical_channel_id
  GROUP BY s.local_channel_id
) m
WHERE h.channel_id=m.channel_id AND h.joined_at >= m.earliest;
UPDATE messages AS m SET created_at=w.latest_at
FROM (SELECT channel_id,max(seq) AS last_seq,max(created_at) AS latest_at FROM messages GROUP BY channel_id) w
WHERE m.channel_id=w.channel_id AND m.seq=w.last_seq AND m.created_at<w.latest_at;
UPDATE messages AS m
SET task_number=t.task_number, task_status=t.status::text,
    task_assignee_type=t.claimed_by_type, task_assignee_id=t.claimed_by_id
FROM tasks t WHERE t.message_id=m.id;

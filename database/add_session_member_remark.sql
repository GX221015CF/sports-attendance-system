-- Add free-text remark for each member's attendance record.
-- The remark can be used for leave notes, injury notes, late reasons,
-- or any other free-form explanation entered by an administrator.

alter table session_members
add column if not exists remark text;

-- ============================================================
-- TC-CONC-002「删除用户后关联数据检查」数据库核验脚本
-- 用途：《测试执行报告.xlsx》执行明细第 128 行 / 测试报告 3.4 节的证据
-- 验证点：若依删除用户为逻辑删除（del_flag: 0 → 2），关联表
--         sys_user_role（角色绑定）/ sys_user_post（岗位绑定）是否同步清理
-- 结论：已验证——关联记录被同步清理，用例通过（无数据一致性缺陷）
-- 数据库：ry-vue
-- ============================================================

-- ---------- 复现步骤（通过接口执行，此处给出对应 SQL 核验）----------
-- 1. 通过 POST /system/user 创建测试用户（body 含 roleIds / postIds）
-- 2. 执行本脚本「删除前」三句，确认三张表均有记录
-- 3. 通过 DELETE /system/user/{userId} 删除该用户
-- 4. 执行本脚本「删除后」三句，确认关联表记录已被清理

-- ========== 删除前：三张表都应查到记录 ==========
-- ① 主表：del_flag 应为 '0'（存在）
SELECT user_id, user_name, nick_name, del_flag
FROM sys_user
WHERE user_name = 'conc002_test';

-- ② 角色绑定表：应有该用户的角色记录
SELECT ur.user_id, ur.role_id, r.role_name
FROM sys_user_role ur
LEFT JOIN sys_role r ON r.role_id = ur.role_id
WHERE ur.user_id = (SELECT user_id FROM sys_user WHERE user_name = 'conc002_test');

-- ③ 岗位绑定表：应有该用户的岗位记录
SELECT up.user_id, up.post_id, p.post_name
FROM sys_user_post up
LEFT JOIN sys_post p ON p.post_id = up.post_id
WHERE up.user_id = (SELECT user_id FROM sys_user WHERE user_name = 'conc002_test');


-- ========== 删除后：主表逻辑删除、两张关联表应为空 ==========
-- ① 主表：del_flag 应变为 '2'（已删除），记录仍存在（逻辑删除特征）
SELECT user_id, user_name, nick_name, del_flag
FROM sys_user
WHERE user_name = 'conc002_test';

-- ② 角色绑定表：应返回空结果集（记录已清理）
--    ⚠️ 把 {user_id} 替换为上面查到的实际 user_id
SELECT * FROM sys_user_role WHERE user_id = {user_id};

-- ③ 岗位绑定表：应返回空结果集（记录已清理）
SELECT * FROM sys_user_post WHERE user_id = {user_id};


-- ========== 实测结果留档（2026-09-26）==========
-- user_id = 248
-- 删除前：sys_user=(248,'conc002_test','0')
--         sys_user_role=(248,1)      ← 已绑定角色
--         sys_user_post=(248,1)      ← 已绑定岗位
-- 删除后：sys_user=(248,'conc002_test','2')  ← 逻辑删除
--         sys_user_role=()           ← ✅ 已清理
--         sys_user_post=()           ← ✅ 已清理
-- 结论：若依在逻辑删除用户时同步清理了关联表，无用例预期缺陷。
--       该结论说明删除用户功能在"关联数据一致性"维度表现正确。


-- 附：常见的数据一致性反例（若出现则为缺陷，本次未出现）
-- 1. sys_user.del_flag 变为 '2'，但 sys_user_role 仍有记录 → 脏数据残留
-- 2. 关联表记录保留且用户被"恢复"时出现重复绑定
-- 3. 删除后 sys_user 物理消失但关联表残留（无逻辑删除机制时）

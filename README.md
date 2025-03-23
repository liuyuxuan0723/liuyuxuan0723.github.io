# Welcome to My Blog

## Hexo 安装
```bash
# 全局安装 Hexo CLI
npm install -g hexo-cli

# 初始化博客项目
hexo init <博客名称>
cd <博客名称>

# 安装依赖
npm install
```

## 常用 Hexo 命令

### 创建新博客文章
```bash
# 创建新文章
hexo new "文章标题"

# 创建新草稿
hexo new draft "草稿标题"

# 将草稿转为文章
hexo publish "草稿标题"
```

### 生成与预览
```bash
# 清除缓存
hexo clean

# 生成静态文件
hexo generate (或简写 hexo g)

# 启动本地服务器预览
hexo server (或简写 hexo s)

# 生成后立即预览
hexo g && hexo s
```

### 部署到 GitHub Pages
```bash
# 部署到远程仓库
make deploy (或简写 hexo d)

# 生成后立即部署
hexo g && hexo d
```

### 其他常用命令
```bash
# 显示 Hexo 版本
hexo version

# 查看 Hexo 帮助文档
hexo help
```




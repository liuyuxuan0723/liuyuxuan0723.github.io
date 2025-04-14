deploy:
	hexo clean
	hexo g -s
	hexo deploy
	git add .
	git commit -m "Site updated: $$(date +"%Y-%m-%d %H:%M:%S")"
	git push origin main -f

run:
	hexo clean
	hexo g -s
	hexo s
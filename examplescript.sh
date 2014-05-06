#!/bin/bash
cat > test.sh << 'EOF'
#!/bin/bash
HOST=192.168.1.5:8080
for i in `seq 1 3`; do
	wget http://$HOST/alive/$HOSTNAME
	#sleep 60
done
wget http://$HOST/done/$HOSTNAME
EOF
chmod +x test.sh
nohup ./test.sh > test.log 2>&1 &
exit

package main

import (
	"bufio"
	"bytes"
	"fmt"
	"math"
	"net"
	"os"
	"strconv"
	"strings"
)

func main() {
	if len(os.Args) < 3 {
		fmt.Println("args error: <redis_addr> <rdb_file_path>")
		return
	}

	netAddr, err := net.ResolveTCPAddr("tcp", os.Args[1])
	if err != nil {
		fmt.Printf("Error resolving address: %v\n", err)
		return
	}

	rdb, err := os.OpenFile(os.Args[2], os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o666)
	if err != nil {
		fmt.Printf("Error open file: %v\n", err)
		return
	}
	defer rdb.Close()

	conn, err := net.DialTCP("tcp", nil, netAddr)
	if err != nil {
		fmt.Printf("Error connecting to server: %v\n", err)
		return
	}
	defer conn.Close()

	// Step 1: 发送 "REPLCONF CAPA EOF"
	err = sendRedisCommand(conn, "REPLCONF", "CAPA", "EOF")
	if err != nil {
		fmt.Printf("Error sending REPLCONF command: %v\n", err)
		return
	}
	response, err := readRedisResponse(conn)
	if err != nil {
		fmt.Printf("Error reading REPLCONF response: %v\n", err)
		return
	}
	if response != "OK" {
		fmt.Printf("Unexpected response for REPLCONF: %s\n", response)
		return
	}
	fmt.Println("Step 1 succeeded: REPLCONF CAPA EOF -> OK")

	// Step 2: 发送 "PSYNC ? -1"
	// err = sendRedisCommand(conn, "PSYNC", "?", "-1")
	err = sendRedisCommand(conn, "SYNC")
	if err != nil {
		fmt.Printf("Error sending PSYNC command: %v\n", err)
		return
	}

	rw := bufio.NewReader(bufio.NewReader(conn))
	var bufBuilder bytes.Buffer
	for {
		b, err := rw.ReadByte()
		if err != nil {
			fmt.Printf("Error reading byte: %v\n", err)
			return
		}

		if b == '\n' && bufBuilder.Len() > 0 {
			bufBuilder.WriteByte(b)
			break
		}

		if b == '\n' {
			continue
		}

		bufBuilder.WriteByte(b)
	}

	const RDB_EOF_MARK_SIZE = 40
	buf := bufBuilder.Bytes()
	if buf[0] == '-' {
		fmt.Printf("SYNC with master failed: %s\n", buf)
		return
	}

	bufEOF := make([]byte, RDB_EOF_MARK_SIZE)

	payload, err, useMark := uint64(0), nil, false
	if bytes.Index(buf[1:], []byte("EOF:")) == 0 && len(buf[5:]) >= RDB_EOF_MARK_SIZE {
		copy(bufEOF, buf[5:])
		payload = math.MaxUint64
		useMark = true
		fmt.Printf("SYNC sent to master, writing bytes of bulk transfer until EOF marker")
	} else {
		payload, err = strconv.ParseUint(string(buf[1:]), 10, 64)
		if err != nil {
			fmt.Printf("Error parsing payload: %v\n", err)
			return
		}
		fmt.Printf("SYNC sent to master, writing %d bytes of bulk transfer", payload)
	}
	fmt.Printf("Step 2 response: %s\n", response)

	maxRead := 4096
	// 用于存储前一次读取的数据的结尾
	buf = make([]byte, maxRead)
	var prevTail []byte
	for payload > uint64(0) {
		targetBytes := maxRead
		if payload < uint64(maxRead) {
			targetBytes = int(payload)
		}

		if prevTail != nil {
			copy(buf, prevTail)
		}

		nread, err := rw.Read(buf[len(prevTail):targetBytes])
		if err != nil {
			fmt.Printf("Error reading bulk transfer: %v\n", err)
			return
		}

		// 更新缓冲区数据
		data := buf[:len(prevTail)+nread]

		if useMark {
			if len(data) >= RDB_EOF_MARK_SIZE && bytes.Equal(data[len(data)-RDB_EOF_MARK_SIZE:], bufEOF) {
				payload -= uint64(len(data[:len(data)-RDB_EOF_MARK_SIZE]))
				rdb.Write(data[:len(data)-RDB_EOF_MARK_SIZE])
				fmt.Printf("%s", string(data[:len(data)-RDB_EOF_MARK_SIZE]))
				fmt.Println("EOF reached")
				break
			}

			// 保存本次数据的结尾部分用于下次拼接
			if len(data) >= RDB_EOF_MARK_SIZE {
				// 写入所有读取的数据
				payload -= uint64(len(data[:len(data)-RDB_EOF_MARK_SIZE]))
				rdb.Write(data[:len(data)-RDB_EOF_MARK_SIZE])
				fmt.Printf("%s", string(data[:len(data)-RDB_EOF_MARK_SIZE]))
				prevTail = data[len(data)-RDB_EOF_MARK_SIZE:]
			} else {
				prevTail = data
			}
		} else {
			payload -= uint64(len(buf[:nread]))
			rdb.Write(buf[:nread])
			fmt.Printf("%s", string(buf[:nread]))
		}
	}

	if useMark {
		payload = math.MaxUint64 - payload
		fmt.Printf("Transfer finished with success after %d bytes\n", payload)
	} else {
		fmt.Printf("Transfer finished with success\n")
	}
}

// sendRedisCommand 构建并发送 Redis 协议的命令
func sendRedisCommand(conn net.Conn, args ...string) error {
	command := buildRedisCommand(args...)
	_, err := conn.Write([]byte(command))
	return err
}

// buildRedisCommand 构建符合 Redis 协议的命令字符串
func buildRedisCommand(args ...string) string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("*%d\r\n", len(args)))
	for _, arg := range args {
		sb.WriteString(fmt.Sprintf("$%d\r\n%s\r\n", len(arg), arg))
	}
	return sb.String()
}

// readRedisResponse 读取 Redis 响应
func readRedisResponse(conn net.Conn) (string, error) {
	reader := bufio.NewReader(conn)
	line, err := reader.ReadString('\n')
	if err != nil {
		return "", err
	}
	line = strings.TrimSpace(line)

	// 简单处理响应，如果是 + 开头的行，表示是状态消息
	if strings.HasPrefix(line, "+") {
		return line[1:], nil
	}

	// 返回原始响应（可以根据需要解析）
	return line, nil
}

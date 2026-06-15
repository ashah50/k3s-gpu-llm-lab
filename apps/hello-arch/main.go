// hello-arch: a tiny HTTP server that reports the node architecture it's
// running on. Used to prove multi-arch (arm64 + amd64) scheduling on the cluster.
package main

import (
	"fmt"
	"net/http"
	"os"
	"runtime"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		host, _ := os.Hostname()
		fmt.Fprintf(w, "hello from pod %s — arch=%s os=%s\n", host, runtime.GOARCH, runtime.GOOS)
	})
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "ok")
	})
	fmt.Println("hello-arch listening on :8080")
	http.ListenAndServe(":8080", nil)
}

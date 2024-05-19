package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"runtime"
	"sort"
	"strings"
	"text/template"
	"time"
)

var startTime time.Time

func uptime() time.Duration {
	return time.Since(startTime)
}

func init() {
	startTime = time.Now()
}

var indexTemplate = template.Must(template.New("Index").Parse(`<!DOCTYPE html>
<html>
<head>
<title>example-app</title>
<style>
body {
	font-family: monospace;
	color: #555;
	background: #e6edf4;
	padding: 1.25rem;
	margin: 0;
}
table {
	background: #fff;
	border: .0625rem solid #c4cdda;
	border-radius: 0 0 .25rem .25rem;
	border-spacing: 0;
    margin-bottom: 1.25rem;
	padding: .75rem 1.25rem;
	text-align: left;
	white-space: pre;
}
table > caption {
	background: #f1f6fb;
	text-align: left;
	font-weight: bold;
	padding: .75rem 1.25rem;
	border: .0625rem solid #c4cdda;
	border-radius: .25rem .25rem 0 0;
	border-bottom: 0;
}
table td, table th {
	padding: .25rem;
}
table > tbody > tr:hover {
	background: #f1f6fb;
}
</style>
</head>
<body>
	<table>
		<caption>Properties</caption>
		<tbody>
			<tr><th>Request</th><td>{{.Request}}</td></tr>
            <tr><th>Client Address</th><td>{{.ClientAddress}}</td></tr>
            <tr><th>Server Address</th><td>{{.ServerAddress}}</td></tr>
			<tr><th>Hostname</th><td>{{.Hostname}}</td></tr>
			<tr><th>Runtime</th><td>{{.Runtime}}</td></tr>
			<tr><th>Os</th><td>{{.Os}}</td></tr>
            <tr><th>Architecture</th><td>{{.Architecture}}</td></tr>
			<tr><th>Uptime</th><td>{{.Uptime}}</td></tr>
		</tbody>
	</table>
    <table>
        <caption>Environment Variables</caption>
        <tbody>
            {{- range .Environment}}
            <tr>
                <th>{{.Name}}</th>
                <td>{{.Value}}</td>
            </tr>
            {{- end}}
        </tbody>
    </table>
    <table>
        <caption>Request Headers</caption>
        <tbody>
            {{- range $header := .RequestHeaders}}
			{{- range .Values }}
            <tr>
                <th>{{$header.Name}}</th>
                <td>{{.}}</td>
            </tr>
            {{- end}}
            {{- end}}
        </tbody>
    </table>
</body>
</html>
`))

type indexData struct {
	Request        string
	ClientAddress  string
	ServerAddress  string
	Hostname       string
	Os             string
	Architecture   string
	Runtime        string
	Uptime         string
	Environment    []nameValuePair
	RequestHeaders headers
}

type nameValuePair struct {
	Name  string
	Value string
}

type nameValuePairs []nameValuePair

func (a nameValuePairs) Len() int           { return len(a) }
func (a nameValuePairs) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a nameValuePairs) Less(i, j int) bool { return a[i].Name < a[j].Name }

type header struct {
	Name   string
	Values []string
}

type headers []header

func headersFromHttpHeaders(httpHeaders http.Header) headers {
	result := make(headers, 0, len(httpHeaders))
	for k := range httpHeaders {
		result = append(result, header{
			Name:   k,
			Values: httpHeaders[k],
		})
	}
	return result
}

func (a headers) Len() int           { return len(a) }
func (a headers) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a headers) Less(i, j int) bool { return strings.ToLower(a[i].Name) < strings.ToLower(a[j].Name) }

func main() {
	log.SetFlags(0)

	log.Printf("%s", runtime.Version())

	var listenAddress = flag.String("listen", ":8000", "Listen address")

	flag.Parse()

	if flag.NArg() != 0 {
		flag.Usage()
		log.Fatalf("\nERROR You MUST NOT pass any positional arguments")
	}

	if *listenAddress == "" || *listenAddress == "no" {
		return
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.Error(w, "Not Found", http.StatusNotFound)
			return
		}

		hostname, err := os.Hostname()
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		environment := make([]nameValuePair, 0)
		for _, v := range os.Environ() {
			parts := strings.SplitN(v, "=", 2)
			name := parts[0]
			value := parts[1]
			switch name {
			case "PATH":
				fallthrough
			case "XDG_DATA_DIRS":
				fallthrough
			case "XDG_CONFIG_DIRS":
				value = strings.Join(
					strings.Split(value, string(os.PathListSeparator)),
					"\n")
			}
			environment = append(environment, nameValuePair{name, value})
		}
		sort.Sort(nameValuePairs(environment))

		headers := headersFromHttpHeaders(r.Header)
		sort.Sort(headers)

		w.Header().Set("Content-Type", "text/html")

		err = indexTemplate.ExecuteTemplate(w, "Index", indexData{
			Request:        fmt.Sprintf("%s %s%s", r.Method, r.Host, r.URL),
			ClientAddress:  r.RemoteAddr,
			ServerAddress:  r.Context().Value(http.LocalAddrContextKey).(net.Addr).String(),
			Hostname:       hostname,
			Os:             runtime.GOOS,
			Architecture:   runtime.GOARCH,
			Runtime:        runtime.Version(),
			Uptime:         uptime().String(),
			Environment:    environment,
			RequestHeaders: headers,
		})
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	})

	fmt.Printf("Listening at http://%s\n", *listenAddress)

	err := http.ListenAndServe(*listenAddress, nil)
	if err != nil {
		log.Fatalf("Failed to ListenAndServe: %v", err)
	}
}

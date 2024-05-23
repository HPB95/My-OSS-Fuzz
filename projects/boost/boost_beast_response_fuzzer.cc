// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <boost/beast.hpp>
#include <boost/beast/_experimental/test/stream.hpp>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
    using namespace boost::beast;

    error_code ec;
    flat_buffer buffer;
    net::io_context ioc;
    test::stream stream{ioc, {reinterpret_cast<const char*>(data), size}};
    stream.close_remote();

    http::chunk_extensions ce;
    http::response_parser<http::dynamic_body> parser;

    auto chunk_header_cb
        = [&ce](std::uint64_t size, string_view extensions, error_code& ev) {
              ce.parse(extensions, ev);
          };

    parser.on_chunk_header(chunk_header_cb);
    http::read(stream, buffer, parser, ec);

    return 0;
}

# 📑 Project: Kitten-Zig Distributed OS (KZD-OS)

Zig로 작성된 베어메탈 커널 위에서 Kitten DSL(Wasm)이 돌아가는 리소스 기반 분산 운영체제입니다.

---

## 1. 시스템 철학 (Core Philosophy)
* **Everything is HTTP**: 모든 하드웨어 및 소프트웨어 자원은 URL을 가지며 CRUD로 통신합니다.
* **Pure Logic in Kitten**: 시스템 제어 로직은 스택 기반 함수형 언어인 Kitten으로 작성되어 안전성을 보장합니다.
* **Hard/Soft Split**: Zig는 하드웨어와 메모리(근육)를 담당하고, Kitten/Wasm은 정책과 로직(두뇌)을 담당합니다.

---

## 2. 기술 스택 (Tech Stack)
* **Kernel**: Zig (Target: `freestanding`)
* **Logic Runtime**: Custom Wasm Interpreter (Written in Zig)
* **Control DSL**: Kitten-inspired DSL (Custom implementation)
  * Kitten(https://github.com/evincarofautumn/kitten) 의 스택 기반 함수형 문법을 차용하되, 우리 OS의 CRUD 시스템 콜에 최적화된 독자적인 DSL을 구축합니다.
* **Communication**: Binary CRUD over Shared Memory (VirtIO Style)

---

## 3. Zig 베어메탈 명세 (Bare-metal Specs)

### 3.1 메모리 관리 (Memory Management)
OS가 없는 환경이므로 `std.heap.page_allocator`를 사용할 수 없습니다. 초기 단계에서는 고정된 메모리 풀을 사용하는 **FixedBufferAllocator**를 활용합니다.

<quote>zig
// 예시: 커널 힙 영역 정의
var kernel_heap: [1024 * 1024]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&kernel_heap);
const allocator = fba.allocator();
<quote>

### 3.2 하드웨어 접근 (Hardware Access)
포인터를 통해 특정 메모리 주소(MMIO)에 직접 접근하여 제어합니다.
* **VGA Text Buffer**: `0xB8000` (x86 환경 글자 출력)
* **Serial Port**: `0x3F8` (디버깅용 로그 출력용 UART)

---

## 4. Wasm 인터프리터 설계 (VM Specs)
Kitten DSL을 실행하기 위한 최소한의 스택 머신 구조입니다.

| 요소 | 설명 |
| :--- | :--- |
| **Stack** | `std.ArrayList(Value)` 혹은 고정 배열 기반 LIFO 구조 |
| **Memory** | Wasm 모듈마다 할당되는 `[]u8` 선형 메모리 (Linear Memory) |
| **Host Functions** | Zig 커널이 Wasm에게 제공하는 CRUD 시스템 콜 인터페이스 |

---

## 5. 개발 로드맵 (Roadmap)

### Phase 1: Bare-metal Hello World
- [ ] `freestanding` 타겟 빌드 설정 (`build.zig`)
- [ ] VGA 버퍼를 이용한 화면 문자 출력 기능 구현
- [ ] 기본적인 Panic Handler 및 Entry Point(`_start`) 설정

### Phase 2: Primitive VM Implementation
- [ ] 스택 기반 정수 연산(Add, Sub) 인터프리터 구현
- [ ] 바이트코드 Fetch-Decode-Execute 루프 작성
- [ ] LEB128 가변 정수 파싱 로직 구현

### Phase 3: Kitten DSL & CRUD
- [ ] Kitten 문법의 Wasm 매핑 규칙 정의
- [ ] `GET/POST` 시스템 콜(Host Function) 연동
- [ ] 공유 메모리를 통한 인터럽트 전광판 설계

---

## 6. Gemini 협업 가이드 (Instruction for AI)
1. **코드 제안 시**: 기존 코드가 있다면 전체를 다시 쓰지 말고 **수정 사항(Diff)**만 보여주세요.
2. **언어 스타일**: 반말이 아닌 **존댓말**로 대화하며 명확하고 간결한 설명을 지향합니다.
3. **지식 한계**: 모르는 내용에 대해서는 추측하지 말고 **모른다고 명시**한 뒤 추가 정보를 요청하세요.
4. **포맷팅**: 수학적 공식은 LaTeX를 사용하되, 단순 단위(10% 등)나 프로그래밍 코드는 마크다운 형식을 따릅니다.

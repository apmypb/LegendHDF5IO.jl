using LegendHDF5IO
using Unitful
using TypedTables
using ArraysOfArrays
using RadiationDetectorSignals

@testset "test wrapper" begin
    @testset "reading and writing" begin
        x = rand(50)
        y = x*u"J"
        vofv1 = VectorOfVectors(fill(x, 50))
        vofv2 = VectorOfVectors(fill(y, 50))
        aofa1 = nestedview(rand(UInt16, 50, 50))
        aofa2 = nestedview(rand(UInt16, 50, 50)*u"m")
        trng = range(0.0u"μs", 10.0u"μs", 50)
        waveform = ArrayOfRDWaveforms((fill(trng, 50), aofa2))
        tbl = Table((a=x, b=y, c=vofv1, d=vofv2, e=aofa1, f=waveform))
        nt = (data1=aofa2, data2=tbl)
        mktempdir(pwd()) do tmp
            path = joinpath(tmp, "tmp.lh5")
            LHDataStore(path, "cw") do f
                f["tmp"] = nt
            end
            # now check if datatypes and values are equal to the original 
            # data, that was written to tmp.lh5
            LHDataStore(path) do f
                NT = f["tmp"]
                @test keys(NT) == keys(nt)
                @test NT.data1[:] == nt.data1
                for (col1, col2) in zip(columns(NT.data2), columns(nt.data2))
                    if isa(col1, ArrayOfRDWaveforms)
                    @testset "check if RDWaveforms are equal" begin
                            @test col1.signal == col2.signal
                            @test col1.time == col2.time
                    end
                    else
                        @test col1 == col2
                    end
                end
            end
        end
    end
    @testset "test append functionality" begin
        x = rand(50)
        y = x*u"J"
        vofv1 = VectorOfVectors(collect(eachcol(rand(55, 50))))
        vofv2 = VectorOfVectors(collect(eachcol(rand(55, 50)*u"m")))
        aofa1 = nestedview(rand(UInt16, 55, 50))
        aofa2 = nestedview(rand(UInt16, 55, 50)*u"m")
        trng = range(0.0u"μs", 10.0u"μs", 55)
        waveform = ArrayOfRDWaveforms((fill(trng, 50), aofa2))
        tbl = Table((a=x, b=y, c=vofv1, d=vofv2, e=aofa1, f=waveform))
        nt = (data1=aofa2, data2=tbl)

        mktempdir(pwd()) do tmp
            path = joinpath(tmp, "tmp.lh5")
            LHDataStore(path, "cw") do f
                f["tmp"] = nt
            end

            # first append data to in-memory-data
            nt2 = (data1=vcat(aofa2, aofa2), data2=vcat(tbl, tbl))

            # append data to on-disk-data
            LHDataStore(path, "cw") do f
                append!(f["tmp/data1"], aofa2)
                append!(f["tmp/data2"], tbl)
                println("size(f[\"tmp/data2\"]) = ", size(f["tmp/data2"]))
            end

            # now check if datatypes and values are equal to the data 
            # that was extended in memory
            println("done appending")
            LHDataStore(path) do f
                NT = f["tmp"]
                println("size(nt2.data2) = ", size(nt2.data2))
                println("size(NT.data2) = ", size(NT.data2))
                @test keys(NT) == keys(nt2)
                @test NT.data1[:] == nt2.data1
                for (col1, col2) in zip(columns(NT.data2), columns(nt2.data2))
                    if isa(col1, ArrayOfRDWaveforms)
                    @testset "check if RDWaveforms are equal" begin
                            @test col1.signal == col2.signal
                            @test col1.time == col2.time
                    end
                    else
                        @test col1 == col2
                    end
                end
            end
        end
    end
end
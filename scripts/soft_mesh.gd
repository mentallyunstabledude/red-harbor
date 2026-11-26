class_name SoftMesh
extends Object
## The Klubnika softness, one generator for the whole cast: a superellipsoid
## slab whose "power" sets the read - near 2 it rounds into a fluid capsule,
## near 4 it stays a box with softened edges - so nothing in the game keeps
## a hard corner. Smooth analytic normals off the implicit surface, one UV
## wrap per part (front lands at the sheet's center) so the painted sheets
## still read like they did on the old boxes.

static func slab(size: Vector3, power := 3.0, rings := 10, around := 14) -> Mesh:
        var a := maxf(size.x, 0.001) * 0.5
        var b := maxf(size.y, 0.001) * 0.5
        var c := maxf(size.z, 0.001) * 0.5
        var e := 2.0 / power

        var verts := PackedVector3Array()
        var norms := PackedVector3Array()
        var uvs := PackedVector2Array()
        var idx := PackedInt32Array()

        # the two poles, then rings between them; the seam sits at the back so
        # u = 0.5 looks the camera in the eye
        var top := verts.size()
        verts.append(Vector3(0, b, 0))
        norms.append(Vector3(0, 1, 0))
        uvs.append(Vector2(0.5, 0.0))
        for j in range(1, rings):
                var phi := PI * float(j) / float(rings)
                var sp := sin(phi)
                var cp := cos(phi)
                var rp := pow(absf(cp), e) * signf(cp)
                var sp_e := pow(absf(sp), e)
                for i in range(around + 1):
                        var th := TAU * float(i) / float(around)
                        # theta starts at the back so the seam hides behind him and the
                        # face center lands mid-sheet (u 0.5) where the paint expects it
                        var x := a * sp_e * pow(absf(sin(th)), e) * signf(sin(th))
                        var z := -c * sp_e * pow(absf(cos(th)), e) * signf(cos(th))
                        verts.append(Vector3(x, b * rp, z))
                        var nx := signf(x) * pow(absf(x / a), power - 1.0)
                        var ny := signf(cp) * pow(absf(cp), power - 1.0)
                        var nz := signf(z) * pow(absf(z / c), power - 1.0)
                        norms.append(Vector3(nx, ny, nz).normalized())
                        uvs.append(Vector2(float(i) / float(around), float(j) / float(rings)))
        var bottom := verts.size()
        verts.append(Vector3(0, -b, 0))
        norms.append(Vector3(0, -1, 0))
        uvs.append(Vector2(0.5, 1.0))

        # top fan
        for i in range(around):
                idx.append(top)
                idx.append(1 + i + 1)
                idx.append(1 + i)
        # quads ring to ring
        for j in range(rings - 2):
                var r0 := 1 + j * (around + 1)
                var r1 := r0 + around + 1
                for i in range(around):
                        idx.append(r0 + i)
                        idx.append(r0 + i + 1)
                        idx.append(r1 + i)
                        idx.append(r0 + i + 1)
                        idx.append(r1 + i + 1)
                        idx.append(r1 + i)
        # bottom fan
        var last0 := 1 + (rings - 2) * (around + 1)
        for i in range(around):
                idx.append(bottom)
                idx.append(last0 + i)
                idx.append(last0 + i + 1)

        var arrays := []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = verts
        arrays[Mesh.ARRAY_NORMAL] = norms
        arrays[Mesh.ARRAY_TEX_UV] = uvs
        arrays[Mesh.ARRAY_INDEX] = idx
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        return mesh
